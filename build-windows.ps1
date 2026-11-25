# SPDX-License-Identifier: GPL-3.0-or-later
param(
    [ValidateSet('Default', 'Debug', 'Release', 'All')]
    [string]$Mode = 'All',
    [ValidateSet('x86_64', 'i386')]
    [string]$TargetCPU = 'x86_64',
    [string]$LazBuild = 'lazbuild.exe',
    [string]$Fpc = 'fpc.exe'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command $LazBuild -ErrorAction SilentlyContinue)) {
    $LazBuild = Join-Path $env:SystemDrive 'lazarus\lazbuild.exe'
    if (-not (Test-Path $LazBuild)) {
        throw 'Install Lazarus with FPC, or pass -LazBuild with the path to lazbuild.exe.'
    }
}
$TargetOS = if ($TargetCPU -eq 'x86_64') { 'win64' } else { 'win32' }
$Modes = if ($Mode -eq 'All') { @('Default', 'Debug', 'Release') } else { @($Mode) }
Push-Location $PSScriptRoot
try {
    foreach ($BuildMode in $Modes) {
        & $LazBuild '--ws=win32' "--cpu=$TargetCPU" "--os=$TargetOS" `
            "--build-mode=$BuildMode" '--pcp=bin/.lazarus-windows' 'pastex.lpi'
        if ($LASTEXITCODE -ne 0) { throw "PasTeX $BuildMode build failed ($LASTEXITCODE)." }
    }
} finally { Pop-Location }
