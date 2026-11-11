$ErrorActionPreference = "Stop"

$contractScript = Join-Path $PSScriptRoot "verify_pr_contract.ps1"
$validBody = Join-Path $PSScriptRoot "fixtures\pr\valid.md"
$missingEvidenceBody = Join-Path $PSScriptRoot "fixtures\pr\missing-evidence.md"
$shellExecutable = (Get-Process -Id $PID).Path

& $shellExecutable -NoProfile -ExecutionPolicy Bypass -File $contractScript `
    -BodyPath $validBody `
    -BaseBranch develop `
    -HeadBranch feature/CW-14-player-ci-guardrails
if ($LASTEXITCODE -ne 0) {
    throw "The valid pull request contract fixture must pass."
}

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& $shellExecutable -NoProfile -ExecutionPolicy Bypass -File $contractScript `
    -BodyPath $missingEvidenceBody `
    -BaseBranch develop `
    -HeadBranch feature/CW-14-player-ci-guardrails *> $null
$missingEvidenceExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorPreference
if ($missingEvidenceExitCode -eq 0) {
    throw "A pull request without Evidence must fail."
}

Write-Output "PASS: pull request contract regression tests"
