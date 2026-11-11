$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
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
    "engine\version.json",
    "engine\README.md",
    "engine\build.ps1",
    "engine\requirements.txt",
    "apps\player-godot\README.md",
    ".github\workflows\player-ci.yml",
    ".github\pull_request_template.md",
    "tests\verify_pr_contract.ps1",
    "tests\test_pr_contract.ps1",
    "docs\agents\ci-guardrails.md",
    "docs\adr\0001-pin-godot-fork-and-preserve-official-compatibility.md"
)

foreach ($relativePath in $requiredFiles) {
    Test-RequiredFile -RelativePath $relativePath
}

$engineVersionPath = Join-Path $repoRoot "engine\version.json"
$engineVersion = $null
if (Test-Path -LiteralPath $engineVersionPath -PathType Leaf) {
    try {
        $engineVersion = Get-Content -LiteralPath $engineVersionPath -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        $failures.Add("engine/version.json must contain valid JSON.")
    }
}

if ($null -ne $engineVersion) {
    if ($engineVersion.schema_version -ne 1) {
        $failures.Add("Engine version manifest must use schema_version 1.")
    }
    if ($engineVersion.godot_version -notmatch '^\d+\.\d+\.\d+$') {
        $failures.Add("Engine version manifest must declare a semantic Godot version.")
    }
    $expectedOfficialRelease = "$($engineVersion.godot_version)-stable"
    if ($engineVersion.official_release -ne $expectedOfficialRelease) {
        $failures.Add("Engine version manifest official_release must match godot_version.")
    }
    if ($engineVersion.source_commit -notmatch '^[0-9a-f]{40}$') {
        $failures.Add("Engine version manifest must pin a 40-character source commit.")
    }
    if ($engineVersion.fork_repository -ne "git@github.com:Dong90/godot.git") {
        $failures.Add("Engine version manifest must identify the approved Godot Fork.")
    }
    $expectedArchiveName = "Godot_v$($expectedOfficialRelease)_win64.exe.zip"
    $expectedArchiveUrl = "https://github.com/godotengine/godot/releases/download/$expectedOfficialRelease/$expectedArchiveName"
    if ($engineVersion.official_windows_archive_url -ne $expectedArchiveUrl) {
        $failures.Add("Engine version manifest must use the matching official Godot Windows release archive.")
    }
    if ($engineVersion.official_windows_archive_sha256 -notmatch '^[0-9A-Fa-f]{64}$') {
        $failures.Add("Engine version manifest must pin the official Windows archive SHA-256.")
    }
    $expectedWindowsExecutable = "Godot_v$($expectedOfficialRelease)_win64.exe"
    if ($engineVersion.official_windows_executable -ne $expectedWindowsExecutable) {
        $failures.Add("Engine version manifest must name the matching official Windows executable.")
    }
    $expectedWindowsConsoleExecutable = "Godot_v$($expectedOfficialRelease)_win64_console.exe"
    if ($engineVersion.official_windows_console_executable -ne $expectedWindowsConsoleExecutable) {
        $failures.Add("Engine version manifest must name the matching official Windows console executable.")
    }
}

$submoduleUrl = git -C $repoRoot config --file .gitmodules --get submodule.engine/godot.url
if ($null -ne $engineVersion -and $submoduleUrl -ne $engineVersion.fork_repository) {
    $failures.Add("Godot Submodule must use Dong90/godot over SSH.")
}

$submoduleBranch = git -C $repoRoot config --file .gitmodules --get submodule.engine/godot.branch
if (-not [string]::IsNullOrWhiteSpace($submoduleBranch)) {
    $failures.Add("Godot Submodule must pin a commit instead of following a branch.")
}

$gitlinkEntry = @(git -C $repoRoot ls-files --stage -- engine/godot)
if ($LASTEXITCODE -ne 0 -or $gitlinkEntry.Count -ne 1) {
    $failures.Add("Repository index must contain exactly one engine/godot Gitlink.")
}
elseif ($gitlinkEntry[0] -notmatch '^160000 (?<commit>[0-9a-f]{40}) \d+\s+engine/godot$') {
    $failures.Add("engine/godot must be stored as a Submodule Gitlink.")
}
elseif ($null -ne $engineVersion -and $Matches['commit'] -ne $engineVersion.source_commit) {
    $failures.Add("The engine/godot Gitlink must match the engine version manifest commit.")
}

$submodulePath = Join-Path $repoRoot "engine\godot"
if (-not (Test-Path -LiteralPath $submodulePath -PathType Container)) {
    $failures.Add("Godot Submodule working tree must be initialized before repository verification.")
}
else {
    $submoduleCommit = git -C $submodulePath rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Godot Submodule working tree must contain a valid checkout.")
    }
    elseif ($null -ne $engineVersion -and $submoduleCommit -ne $engineVersion.source_commit) {
        $failures.Add("Godot Submodule working tree must match the engine version manifest commit.")
    }
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

$playerCiPath = Join-Path $repoRoot ".github\workflows\player-ci.yml"
if (Test-Path -LiteralPath $playerCiPath -PathType Leaf) {
    $playerCi = Get-Content -LiteralPath $playerCiPath -Encoding UTF8 -Raw
    $requiredCiPatterns = @(
        @{ Pattern = '(?m)^name:\s*Player CI\s*$'; Message = "Player CI must expose its stable workflow name." },
        @{ Pattern = '(?m)^\s{2}pull_request:\s*$'; Message = "Player CI must run for pull requests." },
        @{ Pattern = '(?m)^\s{4}branches:\s*\[\s*develop\s*,\s*main\s*\]\s*$'; Message = "Player CI must protect develop and main." },
        @{ Pattern = '(?m)^\s{4}types:\s*\[\s*opened\s*,\s*synchronize\s*,\s*reopened\s*,\s*edited\s*\]\s*$'; Message = "Player CI must revalidate edited pull request bodies." },
        @{ Pattern = '(?m)^permissions:\s*\r?\n\s{2}contents:\s*read\s*$'; Message = "Player CI must use read-only repository permissions." },
        @{ Pattern = '(?m)^\s{2}official-player:\s*$'; Message = "Player CI must expose the official-player check." },
        @{ Pattern = '(?m)^\s{2}fork-player:\s*$'; Message = "Player CI must expose the fork-player check." },
        @{ Pattern = '(?m)^\s{2}pr-contract:\s*$'; Message = "Player CI must expose the pr-contract check." },
        @{ Pattern = 'engine/version\.json'; Message = "Player CI must read the engine version manifest." },
        @{ Pattern = 'tests[\\/]verify_repository\.ps1'; Message = "Player CI must run the repository contract." },
        @{ Pattern = 'tests[\\/]verify_pr_contract\.ps1'; Message = "Player CI must validate pull request bodies." },
        @{ Pattern = 'tests[\\/]run_headless\.ps1'; Message = "Player CI must run the Godot smoke check." },
        @{ Pattern = 'engine[\\/]build\.ps1'; Message = "Player CI must build the pinned Fork." },
        @{ Pattern = 'git status --porcelain'; Message = "Player CI must verify repository hygiene." }
    )

    foreach ($contract in $requiredCiPatterns) {
        if ($playerCi -notmatch $contract.Pattern) {
            $failures.Add($contract.Message)
        }
    }

    if ($playerCi -match '(?m)^\s*pull_request_target:\s*$') {
        $failures.Add("Player CI must not execute pull request code with pull_request_target.")
    }
    if ($playerCi -match '(?m)^\s{2}(?:push|workflow_dispatch):') {
        $failures.Add("Player CI check names must be produced only by pull request validation.")
    }

    $actionReferences = [regex]::Matches($playerCi, '(?m)^\s*(?:-\s+)?uses:\s*([^\s#]+)')
    foreach ($actionReference in $actionReferences) {
        if ($actionReference.Groups[1].Value -notmatch '^[^@]+@[0-9a-f]{40}$') {
            $failures.Add("GitHub Actions dependencies must be pinned to a full commit SHA.")
        }
    }
}

$pullRequestTemplatePath = Join-Path $repoRoot ".github\pull_request_template.md"
if (Test-Path -LiteralPath $pullRequestTemplatePath -PathType Leaf) {
    $pullRequestTemplate = Get-Content -LiteralPath $pullRequestTemplatePath -Encoding UTF8 -Raw
    $requiredTemplatePatterns = @(
        @{ Pattern = '(?m)^## Summary\s*$'; Message = "PR template must include Summary." },
        @{ Pattern = '(?m)^## GitFlow\s*$'; Message = "PR template must include GitFlow." },
        @{ Pattern = '(?m)^## Evidence\s*$'; Message = "PR template must include Evidence." },
        @{ Pattern = '(?m)^## Impact Check\s*$'; Message = "PR template must include Impact Check." },
        @{ Pattern = '(?m)^## Merge Danger\s*$'; Message = "PR template must include Merge Danger." },
        @{ Pattern = 'Refs #<issue>'; Message = "PR template must document develop-target Issue references." },
        @{ Pattern = '\*\*Door:\*\*'; Message = "PR template must classify reversibility." },
        @{ Pattern = '\*\*Blast Radius:\*\*'; Message = "PR template must classify blast radius." }
    )

    foreach ($contract in $requiredTemplatePatterns) {
        if ($pullRequestTemplate -notmatch $contract.Pattern) {
            $failures.Add($contract.Message)
        }
    }
}

$ciGuardrailsPath = Join-Path $repoRoot "docs\agents\ci-guardrails.md"
if (Test-Path -LiteralPath $ciGuardrailsPath -PathType Leaf) {
    $ciGuardrails = Get-Content -LiteralPath $ciGuardrailsPath -Encoding UTF8 -Raw
    foreach ($requiredText in @(
        "engine/version.json",
        "pr-contract",
        "official-player",
        "fork-player",
        "--body-file -",
        "main",
        "develop"
    )) {
        if (-not $ciGuardrails.Contains($requiredText)) {
            $failures.Add("CI guardrail documentation must include '$requiredText'.")
        }
    }
}

$agentInstructions = Get-Content -LiteralPath (Join-Path $repoRoot "AGENTS.md") -Encoding UTF8 -Raw
if ($agentInstructions -notmatch 'docs/agents/ci-guardrails\.md') {
    $failures.Add("AGENTS.md must point CI and branch-protection work to the guardrail documentation.")
}

$developmentWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot "docs\agents\development-workflow.md") -Encoding UTF8 -Raw
if ($developmentWorkflow -notmatch 'Future milestone gates are not current Ticket blockers') {
    $failures.Add("Development workflow must keep future milestone gates out of current Ticket reviews.")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: CineWeave repository startup contract"
