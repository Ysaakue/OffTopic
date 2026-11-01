<#
.SYNOPSIS
    Runs every check of the workspace. A phase only closes when this is green.

.DESCRIPTION
    1. Flutter pin (.fvmrc) and code generation freshness.
    2. Dart: format, analyze, tests with coverage, coverage gate.
    3. Kotlin (voice_platform): unit tests, Kover gate, ktlint.
    4. C++ core in WSL (tools/verify_core.sh): debug, ASan+UBSan, TSan,
       gcovr gate and a short fuzz run.

.PARAMETER SkipCodegen
    Do not regenerate ffigen / Pigeon / l10n output before checking.

.PARAMETER SkipAndroid
    Skip the Gradle (Kotlin) checks.

.PARAMETER SkipCore
    Skip the WSL (C++) checks.

.EXAMPLE
    ./tools/verify.ps1
    ./tools/verify.ps1 -SkipCore
#>
[CmdletBinding()]
param(
    [switch] $SkipCodegen,
    [switch] $SkipAndroid,
    [switch] $SkipCore
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')

$repoRoot = Get-RepoRoot
$dartPackages = @('app', 'packages/voice_core', 'packages/voice_platform')
$generatedPaths = @(
    'packages/voice_core/lib/src/generated',
    'packages/voice_platform/lib/src/generated',
    'packages/voice_platform/android/src/main/kotlin/com/isaacgeraldo/offtopic/voiceplatform/generated',
    'packages/voice_platform/ios/voice_platform/Sources/voice_platform/VoicePlatformApi.g.swift',
    'app/lib/l10n/generated'
)
$started = Get-Date

Invoke-Step 'Flutter pin (.fvmrc)' { Assert-Fvm -RepoRoot $repoRoot; Write-Host 'fvm OK' }

if (-not $SkipCodegen) {
    Invoke-Step 'Code generation is up to date' {
        & (Join-Path $PSScriptRoot 'codegen.ps1')
        Push-Location $repoRoot
        try {
            # Only tracked files can be stale; untracked output is new, not stale.
            $stale = git status --porcelain -- $generatedPaths | Where-Object { $_ -notmatch '^\?\?' }
        } finally {
            Pop-Location
        }
        if ($stale) {
            throw "Generated code was out of date and has been regenerated; review and commit it:`n$($stale -join "`n")"
        }
    }
}

Invoke-Step 'Dart format' {
    Invoke-Native -WorkingDirectory $repoRoot fvm dart format --output=none --set-exit-if-changed app packages tools
}

Invoke-Step 'Dart analyze' {
    Invoke-Native -WorkingDirectory $repoRoot fvm flutter analyze
}

Invoke-Step 'Dart tests with coverage' {
    Invoke-Native -WorkingDirectory $repoRoot fvm dart run tools/coverage/coverage_gate.dart prepare
    try {
        foreach ($package in $dartPackages) {
            Write-Host "-- $package"
            Invoke-Native -WorkingDirectory (Join-Path $repoRoot $package) fvm flutter test --coverage --reporter=compact
        }
    } finally {
        Invoke-Native -WorkingDirectory $repoRoot fvm dart run tools/coverage/coverage_gate.dart clean
    }
}

Invoke-Step 'Dart coverage gate' {
    Invoke-Native -WorkingDirectory $repoRoot fvm dart run tools/coverage/coverage_gate.dart check
}

if (-not $SkipAndroid) {
    Invoke-Step 'Kotlin tests, Kover gate and ktlint (voice_platform)' {
        # Robolectric for SDK 37 needs Java 21: use the JDK Flutter itself uses.
        $previousJavaHome = $env:JAVA_HOME
        $env:JAVA_HOME = Get-FlutterJdk
        try {
            Invoke-Native -WorkingDirectory (Join-Path $repoRoot 'app/android') .\gradlew.bat --console=plain `
                :voice_platform:testDebugUnitTest :voice_platform:koverVerifyDebug `
                :voice_platform:koverHtmlReportDebug :voice_platform:ktlintCheck
        } finally {
            $env:JAVA_HOME = $previousJavaHome
        }
        Write-Host 'Kover report: app/build/voice_platform/reports/kover/htmlDebug/index.html'
    }
}

if (-not $SkipCore) {
    Invoke-Step "C++ core in WSL ($WslDistro)" {
        # Called directly: PowerShell would bind '-d' and '--' as its own tokens.
        & wsl.exe '-d' $WslDistro '--cd' $repoRoot '--' 'bash' 'tools/verify_core.sh'
        if ($LASTEXITCODE -ne 0) {
            throw "tools/verify_core.sh failed with exit code $LASTEXITCODE."
        }
    }
}

$elapsed = [int]((Get-Date) - $started).TotalSeconds
Write-Host "`nAll checks passed in ${elapsed}s." -ForegroundColor Green
