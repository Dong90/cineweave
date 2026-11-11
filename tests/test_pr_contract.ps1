$ErrorActionPreference = "Stop"

$contractScript = Join-Path $PSScriptRoot "verify_pr_contract.ps1"
$validBody = Join-Path $PSScriptRoot "fixtures\pr\valid.md"
$shellExecutable = (Get-Process -Id $PID).Path

& $shellExecutable -NoProfile -ExecutionPolicy Bypass -File $contractScript `
    -BodyPath $validBody `
    -BaseBranch develop `
    -HeadBranch feature/CW-14-player-ci-guardrails
if ($LASTEXITCODE -ne 0) {
    throw "The valid pull request contract fixture must pass."
}

$invalidBodies = @(
    @{
        Path = Join-Path $PSScriptRoot "fixtures\pr\missing-evidence.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "Evidence"
    },
    @{
        Path = Join-Path $PSScriptRoot "fixtures\pr\missing-issue.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "an Issue reference"
    },
    @{
        Path = Join-Path $PSScriptRoot "fixtures\pr\missing-merge-danger.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "Merge Danger"
    },
    @{
        Path = Join-Path $PSScriptRoot "fixtures\pr\missing-impact-item.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "the complete Impact Check"
    },
    @{
        Path = Join-Path $PSScriptRoot "fixtures\pr\placeholder-evidence.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "non-placeholder Evidence"
    },
    @{
        Path = Join-Path $PSScriptRoot "fixtures\pr\placeholder-blast-radius.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "a non-placeholder blast radius"
    },
    @{
        Path = Join-Path (Split-Path -Parent $PSScriptRoot) ".github\pull_request_template.md"
        Base = "develop"
        Head = "feature/CW-14-player-ci-guardrails"
        Behavior = "filled template values"
    },
    @{
        Path = $validBody
        Base = "develop"
        Head = "feature/CW-99-wrong-ticket"
        Behavior = "a matching branch Ticket"
    },
    @{
        Path = $validBody
        Base = "main"
        Head = "chore/CW-14-bypass"
        Behavior = "a valid main source branch"
    }
)

foreach ($invalidBody in $invalidBodies) {
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & $shellExecutable -NoProfile -ExecutionPolicy Bypass -File $contractScript `
        -BodyPath $invalidBody.Path `
        -BaseBranch $invalidBody.Base `
        -HeadBranch $invalidBody.Head *> $null
    $invalidExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    if ($invalidExitCode -eq 0) {
        throw "A pull request without $($invalidBody.Behavior) must fail."
    }
}

Write-Output "PASS: pull request contract regression tests"
exit 0
