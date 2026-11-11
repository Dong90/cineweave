$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedGodotCommit = "ed1daf0bf001b61586d9930840f2f1394092c079"
$failures = [System.Collections.Generic.List[string]]::new()

function Test-RequiredFile {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $RelativePath")
    }
}

$requiredFiles = @(
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "engine\README.md",
    "engine\build.ps1",
    "engine\requirements.txt",
    "apps\player-godot\README.md",
    "docs\adr\0001-pin-godot-fork-and-preserve-official-compatibility.md"
)

foreach ($relativePath in $requiredFiles) {
    Test-RequiredFile -RelativePath $relativePath
}

$submoduleUrl = git -C $repoRoot config --file .gitmodules --get submodule.engine/godot.url
if ($submoduleUrl -ne "git@github.com:Dong90/godot.git") {
    $failures.Add("Godot Submodule must use Dong90/godot over SSH.")
}

$submoduleBranch = git -C $repoRoot config --file .gitmodules --get submodule.engine/godot.branch
if (-not [string]::IsNullOrWhiteSpace($submoduleBranch)) {
    $failures.Add("Godot Submodule must pin a commit instead of following a branch.")
}

$submoduleCommit = git -C (Join-Path $repoRoot "engine\godot") rev-parse HEAD
if ($submoduleCommit -ne $expectedGodotCommit) {
    $failures.Add("Godot Submodule must pin official 4.7.2 commit $expectedGodotCommit.")
}

$glossary = Get-Content -LiteralPath (Join-Path $repoRoot "GLOSSARY.md") -Encoding UTF8 -Raw
if ($glossary -notmatch "(?m)^## StoryPack") {
    $failures.Add("GLOSSARY.md must define the StoryPack family term.")
}

$licensePath = Join-Path $repoRoot "LICENSE"
if ((Test-Path -LiteralPath $licensePath) -and (Get-Content -LiteralPath $licensePath -Raw) -notmatch "MIT License") {
    $failures.Add("Root LICENSE must contain the MIT License.")
}

$buildScriptPath = Join-Path $repoRoot "engine\build.ps1"
if (Test-Path -LiteralPath $buildScriptPath) {
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $buildScriptPath,
        [ref]$null,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $failures.Add("engine/build.ps1 must parse without PowerShell syntax errors.")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: CineWeave repository startup contract"
