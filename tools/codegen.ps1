<#
.SYNOPSIS
    Regenerates every generated source of the workspace.

.DESCRIPTION
    - voice_core:     Dart FFI bindings from include/voice_core.h (ffigen).
    - voice_platform: Dart, Kotlin and Swift channels from pigeons/ (Pigeon).
    - app:            localizations from lib/l10n/*.arb (gen-l10n).

    libclang.dll (used by ffigen) is taken from the pinned Android NDK and needs
    its own directory on PATH to load its sibling DLLs.

.EXAMPLE
    ./tools/codegen.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')

$repoRoot = Get-RepoRoot
Assert-Fvm -RepoRoot $repoRoot

$llvmBin = Join-Path (Get-AndroidSdkPath) "ndk/$NdkVersion/toolchains/llvm/prebuilt/windows-x86_64/bin"
if (-not (Test-Path (Join-Path $llvmBin 'libclang.dll'))) {
    throw "libclang.dll not found in $llvmBin. Install NDK $NdkVersion (see docs/DEPENDENCIES.md)."
}
$env:Path = "$llvmBin;$env:Path"

Invoke-Step 'ffigen (voice_core)' {
    Invoke-Native -WorkingDirectory "$repoRoot/packages/voice_core" fvm dart run tool/ffigen.dart
}
Invoke-Step 'pigeon (voice_platform)' {
    Invoke-Native -WorkingDirectory "$repoRoot/packages/voice_platform" fvm dart run pigeon --input pigeons/voice_platform_api.dart
    # Pigeon does not run the formatter of the pinned SDK; keep the output stable.
    Invoke-Native -WorkingDirectory "$repoRoot/packages/voice_platform" fvm dart format lib/src/generated
}
Invoke-Step 'gen-l10n (app)' {
    Invoke-Native -WorkingDirectory "$repoRoot/app" fvm flutter gen-l10n
}
Write-Host "`nCode generation finished." -ForegroundColor Green
