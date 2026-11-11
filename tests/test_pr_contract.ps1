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
    @{ File = "missing-evidence.md"; Behavior = "Evidence" },
    @{ File = "missing-issue.md"; Behavior = "an Issue reference" },
    @{ File = "missing-merge-danger.md"; Behavior = "Merge Danger" }
)

foreach ($invalidBody in $invalidBodies) {
    $bodyPath = Join-Path $PSScriptRoot ("fixtures\pr\{0}" -f $invalidBody.File)
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & $shellExecutable -NoProfile -ExecutionPolicy Bypass -File $contractScript `
        -BodyPath $bodyPath `
        -BaseBranch develop `
        -HeadBranch feature/CW-14-player-ci-guardrails *> $null
    $invalidExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorPreference
    if ($invalidExitCode -eq 0) {
        throw "A pull request without $($invalidBody.Behavior) must fail."
    }
}

Write-Output "PASS: pull request contract regression tests"
