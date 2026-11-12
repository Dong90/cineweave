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
    "tests\verify_storypack_copy.ps1",
    "tools\content\sync_storypacks.ps1",
    "tools\media\generate_zero_echo.ps1",
    "tools\release\windows-export.json",
    "tools\release\export_windows.ps1",
    "tests\test_windows_export_contract.ps1",
    "tests\verify_windows_export.ps1",
    "apps\player-godot\export_presets.cfg",
    "docs\release\V0.1-WINDOWS.md",
    "docs\release\V0.1-BUNDLE-README.txt",
    "content\samples\zero-echo\storypack.json",
    "content\samples\zero-echo\media\zero-echo.ogv",
    "content\samples\zero-echo\media\media-manifest.json",
    "content\samples\zero-echo\media\platform-2357.ogv",
    "content\samples\zero-echo\media\future-warning.ogv",
    "content\samples\zero-echo\media\midnight-train-arrives.ogv",
    "content\samples\zero-echo\media\board-loop-reveal.ogv",
    "content\samples\zero-echo\media\leave-to-0001.ogv",
    "content\samples\zero-echo\ASSET_SOURCE.md",
    "apps\player-godot\content\zero-echo\storypack.json",
    "apps\player-godot\content\zero-echo\media\zero-echo.ogv",
    "apps\player-godot\content\zero-echo\media\platform-2357.ogv",
    "apps\player-godot\content\zero-echo\media\platform-2357.ogv.uid",
    "apps\player-godot\content\zero-echo\media\future-warning.ogv",
    "apps\player-godot\content\zero-echo\media\future-warning.ogv.uid",
    "apps\player-godot\content\zero-echo\media\midnight-train-arrives.ogv",
    "apps\player-godot\content\zero-echo\media\midnight-train-arrives.ogv.uid",
    "apps\player-godot\content\zero-echo\media\board-loop-reveal.ogv",
    "apps\player-godot\content\zero-echo\media\board-loop-reveal.ogv.uid",
    "apps\player-godot\content\zero-echo\media\leave-to-0001.ogv",
    "apps\player-godot\content\zero-echo\media\leave-to-0001.ogv.uid",
    "apps\player-godot\assets\fonts\noto-sans-sc\NotoSansSC-Variable.ttf",
    "apps\player-godot\assets\fonts\noto-sans-sc\NotoSansSC-Variable.ttf.import",
    "apps\player-godot\assets\fonts\noto-sans-sc\OFL.txt",
    "apps\player-godot\assets\fonts\noto-sans-sc\SOURCE.md",
    "licenses\NotoSansSC-OFL-1.1.txt",
    "docs\agents\ci-guardrails.md",
    "docs\adr\0001-pin-godot-fork-and-preserve-official-compatibility.md"
)

foreach ($relativePath in $requiredFiles) {
    Test-RequiredFile -RelativePath $relativePath
}

$fontPath = Join-Path $repoRoot "apps\player-godot\assets\fonts\noto-sans-sc\NotoSansSC-Variable.ttf"
if (Test-Path -LiteralPath $fontPath -PathType Leaf) {
    $fontHash = (Get-FileHash -LiteralPath $fontPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($fontHash -ne "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da") {
        $failures.Add("Bundled Noto Sans SC must match the approved pinned Google Fonts artifact.")
    }
}

$fontLicensePath = Join-Path $repoRoot "apps\player-godot\assets\fonts\noto-sans-sc\OFL.txt"
$releaseFontLicensePath = Join-Path $repoRoot "licenses\NotoSansSC-OFL-1.1.txt"
if (
    (Test-Path -LiteralPath $fontLicensePath -PathType Leaf) -and
    (Test-Path -LiteralPath $releaseFontLicensePath -PathType Leaf) -and
    (Get-FileHash -LiteralPath $fontLicensePath -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $releaseFontLicensePath -Algorithm SHA256).Hash
) {
    $failures.Add("Release font license must match the OFL text bundled beside Noto Sans SC.")
}
if (Test-Path -LiteralPath $fontLicensePath -PathType Leaf) {
    $fontLicenseHash = (Get-FileHash -LiteralPath $fontLicensePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($fontLicenseHash -ne "1c05c68c34f9708415aada51f17e1b0092d2cea709bf4a94cd38114f9e73d7d9") {
        $failures.Add("Bundled OFL text must match the pinned Google Fonts distribution bytes.")
    }
}

$assetSourcePath = Join-Path $repoRoot "content\samples\zero-echo\ASSET_SOURCE.md"
if (Test-Path -LiteralPath $assetSourcePath -PathType Leaf) {
    $assetSource = Get-Content -LiteralPath $assetSourcePath -Encoding UTF8 -Raw
    foreach ($requiredRightsText in @("All rights reserved", "SIL Open Font License 1.1", "MIT License", "media-manifest.json")) {
        if (-not $assetSource.Contains($requiredRightsText)) {
            $failures.Add("Zero-echo rights record must include '$requiredRightsText'.")
        }
    }
}

$thirdPartyNoticesPath = Join-Path $repoRoot "THIRD_PARTY_NOTICES.md"
if (Test-Path -LiteralPath $thirdPartyNoticesPath -PathType Leaf) {
    $thirdPartyNotices = Get-Content -LiteralPath $thirdPartyNoticesPath -Encoding UTF8 -Raw
    foreach ($requiredNoticeText in @("Noto Sans SC", "SIL Open Font License 1.1", "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da")) {
        if (-not $thirdPartyNotices.Contains($requiredNoticeText)) {
            $failures.Add("Third-party notices must include '$requiredNoticeText'.")
        }
    }
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

foreach ($scriptRelativePath in @(
    "tools\media\generate_zero_echo.ps1",
    "tools\content\sync_storypacks.ps1",
    "tools\release\export_windows.ps1",
    "tests\verify_storypack_copy.ps1",
    "tests\test_windows_export_contract.ps1",
    "tests\verify_windows_export.ps1"
)) {
    $scriptPath = Join-Path $repoRoot $scriptRelativePath
    if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
        $scriptParseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath,
            [ref]$null,
            [ref]$scriptParseErrors
        )
        if ($scriptParseErrors.Count -gt 0) {
            $failures.Add("$scriptRelativePath must parse without PowerShell syntax errors.")
        }
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
        @{ Pattern = '(?m)^\s+- name:\s*Detect engine-impacting changes\s*$'; Message = "Player CI must detect whether the pinned Fork inputs changed." },
        @{ Pattern = 'BASE_SHA:\s*\$\{\{\s*github\.event\.pull_request\.base\.sha\s*\}\}'; Message = "Fork scope detection must use the pull request base SHA." },
        @{ Pattern = 'git diff --name-only \$env:BASE_SHA HEAD -- \.gitmodules engine'; Message = "Fork scope detection must compare the pull request base to HEAD and only inspect engine inputs." },
        @{ Pattern = '(?m)^\s+- name:\s*Skip unchanged Fork build\s*$'; Message = "Player CI must report when an unchanged Fork build is skipped." },
        @{ Pattern = 'git status --porcelain'; Message = "Player CI must verify repository hygiene." }
    )

    foreach ($contract in $requiredCiPatterns) {
        if ($playerCi -notmatch $contract.Pattern) {
            $failures.Add($contract.Message)
        }
    }

    $guardedForkSteps = @(
        "Initialize the pinned Godot source",
        "Build the pinned Fork",
        "Locate the Fork console executable",
        "Run the Fork Player smoke check",
        "Start the Fork Player main scene",
        "Verify Fork-run repository hygiene"
    )
    foreach ($stepName in $guardedForkSteps) {
        $guardedStepPattern = (
            "(?m)^\s+- name:\s*{0}\s*\r?\n" +
            "\s+if:\s+steps\.fork-scope\.outputs\.required\s+==\s+'true'\s*$"
        ) -f [regex]::Escape($stepName)
        if ($playerCi -notmatch $guardedStepPattern) {
            $failures.Add("Fork step '$stepName' must be guarded by engine-change detection.")
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

$headlessRunnerPath = Join-Path $repoRoot "tests\run_headless.ps1"
if (Test-Path -LiteralPath $headlessRunnerPath -PathType Leaf) {
    $headlessRunner = Get-Content -LiteralPath $headlessRunnerPath -Encoding UTF8 -Raw
    if ($headlessRunner -notmatch '--headless\s+--path\s+\$projectPath\s+--import') {
        $failures.Add("Headless Player tests must import project assets before loading the test scene.")
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

$storyPackCopyCheck = Join-Path $repoRoot "tests\verify_storypack_copy.ps1"
if (Test-Path -LiteralPath $storyPackCopyCheck -PathType Leaf) {
    & $storyPackCopyCheck
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Authoritative StoryPack content and its Godot copy must match.")
    }
}

$windowsExportContractCheck = Join-Path $repoRoot "tests\test_windows_export_contract.ps1"
if (Test-Path -LiteralPath $windowsExportContractCheck -PathType Leaf) {
    & $windowsExportContractCheck
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Windows export configuration and offline contract must pass.")
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: CineWeave repository startup contract"
