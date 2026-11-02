# Shared helpers for the PowerShell tools (codegen.ps1, verify.ps1).
# Dot-source it:  . (Join-Path $PSScriptRoot 'lib/common.ps1')

Set-StrictMode -Version Latest

# Pinned toolchain versions (keep in sync with docs/DEPENDENCIES.md).
$script:NdkVersion = '30.0.16248370'
$script:WslDistro = 'Ubuntu-26.04'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-AndroidSdkPath {
    foreach ($candidate in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'))) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }
    throw 'Android SDK not found. Set ANDROID_HOME (see docs/DEPENDENCIES.md).'
}

# Makes sure fvm is reachable and that the active SDK matches .fvmrc.
function Assert-Fvm {
    param([Parameter(Mandatory)] [string] $RepoRoot)

    $pubBin = Join-Path $env:LOCALAPPDATA 'Pub\Cache\bin'
    if ((Test-Path $pubBin) -and (($env:Path -split ';') -notcontains $pubBin)) {
        $env:Path = "$env:Path;$pubBin"
    }
    if (-not (Get-Command fvm -ErrorAction SilentlyContinue)) {
        throw 'fvm not found. Install it with: dart pub global activate fvm (see docs/DEPENDENCIES.md).'
    }

    $expected = (Get-Content (Join-Path $RepoRoot '.fvmrc') -Raw | ConvertFrom-Json).flutter
    $versionFile = Join-Path $RepoRoot ".fvm\versions\$expected\bin\cache\flutter.version.json"
    if (-not (Test-Path $versionFile)) {
        throw "Flutter $expected is not set up for this project. Run: fvm install $expected; fvm use $expected"
    }
    $active = (Get-Content $versionFile -Raw | ConvertFrom-Json).frameworkVersion
    if ($active -ne $expected) {
        throw "Active Flutter SDK is $active, but .fvmrc pins $expected. Run: fvm use $expected"
    }
}

# The JDK Flutter itself uses for Android builds (Android Studio's JBR).
function Get-FlutterJdk {
    $doctor = & fvm flutter doctor -v 2>$null | Out-String
    $match = [regex]::Match($doctor, 'Java binary at:\s*(?<path>.+?)\\bin\\java')
    if (-not $match.Success) {
        throw 'Could not find the JDK used by Flutter (fvm flutter doctor -v).'
    }
    return $match.Groups['path'].Value.Trim()
}

# SHA-256 of every file under the given repo-relative paths (files or folders).
function Get-GeneratedHashes {
    param(
        [Parameter(Mandatory)] [string] $RepoRoot,
        [Parameter(Mandatory)] [string[]] $Paths
    )
    $hashes = @{}
    foreach ($path in $Paths) {
        $fullPath = Join-Path $RepoRoot $path
        if (Test-Path $fullPath) {
            Get-ChildItem $fullPath -File -Recurse | ForEach-Object {
                $hashes[$_.FullName.Substring($RepoRoot.Length + 1)] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
            }
        }
    }
    return $hashes
}

function Invoke-Step {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [scriptblock] $Action
    )
    Write-Host "`n==> $Name" -ForegroundColor Cyan
    & $Action
}

# Runs a native command and throws when it fails. Only the exit code decides:
# tools such as dart print progress on stderr, which Windows PowerShell would
# otherwise turn into terminating errors when the output is redirected.
function Invoke-Native {
    param(
        [string] $WorkingDirectory = (Get-Location).Path,
        [Parameter(Mandatory, Position = 0)] [string] $Command,
        [Parameter(ValueFromRemainingArguments)] [string[]] $Arguments
    )
    Push-Location $WorkingDirectory
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE (in $WorkingDirectory)."
        }
    } finally {
        $ErrorActionPreference = $previousPreference
        Pop-Location
    }
}
