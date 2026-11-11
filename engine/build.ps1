[CmdletBinding()]
param(
    [ValidateSet("editor", "template_debug", "template_release")]
    [string]$Target = "editor",

    [ValidateRange(1, 256)]
    [int]$Jobs = [Environment]::ProcessorCount,

    [switch]$Bootstrap,
    [switch]$DevBuild
)

$ErrorActionPreference = "Stop"

$engineRoot = $PSScriptRoot
$sourceRoot = Join-Path $engineRoot "godot"
$sconstructPath = Join-Path $sourceRoot "SConstruct"
$virtualEnvironment = Join-Path $engineRoot ".venv"
$virtualPython = Join-Path $virtualEnvironment "Scripts\python.exe"
$requirementsPath = Join-Path $engineRoot "requirements.txt"

if (-not (Test-Path -LiteralPath $sconstructPath -PathType Leaf)) {
    throw "Godot source is missing. Run: git submodule update --init engine/godot"
}

if ($Bootstrap) {
    $systemPython = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $systemPython) {
        throw "Python 3 is required to bootstrap the Godot build environment."
    }

    if (-not (Test-Path -LiteralPath $virtualPython -PathType Leaf)) {
        & $systemPython.Source -m venv $virtualEnvironment
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create the engine Python virtual environment."
        }
    }

    & $virtualPython -m pip install --disable-pip-version-check --requirement $requirementsPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install the pinned Godot build dependencies."
    }
}

if (-not (Test-Path -LiteralPath $virtualPython -PathType Leaf)) {
    throw "Build environment is missing. Run engine/build.ps1 -Bootstrap first."
}

$sconsArguments = @(
    "-m",
    "SCons",
    "platform=windows",
    "target=$Target",
    "arch=x86_64",
    "accesskit=no",
    "angle=no",
    "d3d12=no",
    "-j$Jobs"
)

if ($DevBuild) {
    $sconsArguments += "dev_build=yes"
}

Push-Location $sourceRoot
try {
    & $virtualPython @sconsArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Godot $Target build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$binPath = Join-Path $sourceRoot "bin"
$artifacts = Get-ChildItem -LiteralPath $binPath -Filter "godot.windows.$Target*.exe" -ErrorAction SilentlyContinue
if ($artifacts.Count -eq 0) {
    throw "The build completed without a discoverable Windows $Target executable."
}

$artifacts | Select-Object -ExpandProperty FullName
