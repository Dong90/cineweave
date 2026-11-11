[CmdletBinding(DefaultParameterSetName = "Event")]
param(
    [Parameter(ParameterSetName = "Event")]
    [string]$EventPath = $env:GITHUB_EVENT_PATH,

    [Parameter(Mandatory, ParameterSetName = "Body")]
    [string]$BodyPath,

    [Parameter(Mandatory, ParameterSetName = "Body")]
    [string]$BaseBranch,

    [Parameter(Mandatory, ParameterSetName = "Body")]
    [string]$HeadBranch
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()

if ($PSCmdlet.ParameterSetName -eq "Body") {
    if (-not (Test-Path -LiteralPath $BodyPath -PathType Leaf)) {
        Write-Error "Pull request body file was not found: $BodyPath"
        exit 2
    }
    $body = Get-Content -LiteralPath $BodyPath -Encoding UTF8 -Raw
}
else {
    if ([string]::IsNullOrWhiteSpace($EventPath) -or -not (Test-Path -LiteralPath $EventPath -PathType Leaf)) {
        Write-Error "GitHub pull request event payload was not found."
        exit 2
    }

    try {
        $event = Get-Content -LiteralPath $EventPath -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "GitHub pull request event payload is invalid JSON."
        exit 2
    }

    if ($null -eq $event.pull_request) {
        Write-Error "GitHub event payload does not contain a pull request."
        exit 2
    }

    $body = [string]$event.pull_request.body
    $BaseBranch = [string]$event.pull_request.base.ref
    $HeadBranch = [string]$event.pull_request.head.ref
}

$bodyWithoutComments = [regex]::Replace($body, '(?s)<!--.*?-->', '')

function Test-ConcreteValue {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -notmatch '<[^>]+>'
}

$requiredSections = @("Summary", "GitFlow", "Evidence", "Impact Check", "Merge Danger")
foreach ($section in $requiredSections) {
    if ($bodyWithoutComments -notmatch "(?m)^## $([regex]::Escape($section))\s*$") {
        $failures.Add("Pull request body must include the '$section' section.")
    }
}

$branchType = $null
$ticketNumber = $null
$developmentBranchMatch = [regex]::Match(
    $HeadBranch,
    '^(?<type>feature|bugfix)/CW-(?<issue>\d+)-(?<slug>[a-z0-9]+(?:-[a-z0-9]+)*)$'
)
$releaseBranchMatch = [regex]::Match(
    $HeadBranch,
    '^(?<type>release|hotfix)/(?<version>\d+\.\d+\.\d+)$'
)

if ($developmentBranchMatch.Success) {
    $branchType = $developmentBranchMatch.Groups['type'].Value
    $ticketNumber = $developmentBranchMatch.Groups['issue'].Value
    if ($BaseBranch -ne "develop") {
        $failures.Add("Feature and bugfix pull requests must target develop.")
    }
    if ($bodyWithoutComments -notmatch "(?im)^\s*Refs\s+#$([regex]::Escape($ticketNumber))\s*$") {
        $failures.Add("The Ticket in 'Refs #<issue>' must match CW-$ticketNumber in the source branch.")
    }
}
elseif ($releaseBranchMatch.Success) {
    $branchType = $releaseBranchMatch.Groups['type'].Value
    if ($BaseBranch -notin @("main", "develop")) {
        $failures.Add("Release and hotfix pull requests must target main or their required develop back-merge.")
    }
}
else {
    $failures.Add("Source branch must follow feature/CW-<issue>-<slug>, bugfix/CW-<issue>-<slug>, release/<version>, or hotfix/<version>.")
}

if ($BaseBranch -eq "main" -and -not $releaseBranchMatch.Success) {
    $failures.Add("Only release and hotfix pull requests may target main.")
}
elseif ($BaseBranch -notin @("main", "develop")) {
    $failures.Add("Pull requests governed by Player CI must target develop or main.")
}

if ($null -ne $branchType) {
    $expectedType = (Get-Culture).TextInfo.ToTitleCase($branchType)
    $sourcePattern = "(?im)^- Source:\s*(?:\x60)?$([regex]::Escape($HeadBranch))(?:\x60)?\s*$"
    $targetPattern = "(?im)^- Target:\s*(?:\x60)?$([regex]::Escape($BaseBranch))(?:\x60)?\s*$"
    $typePattern = "(?im)^- Type:\s*$([regex]::Escape($expectedType))\s*$"

    if ($bodyWithoutComments -notmatch $sourcePattern) {
        $failures.Add("GitFlow Source must match the pull request head branch.")
    }
    if ($bodyWithoutComments -notmatch $targetPattern) {
        $failures.Add("GitFlow Target must match the pull request base branch.")
    }
    if ($bodyWithoutComments -notmatch $typePattern) {
        $failures.Add("GitFlow Type must match the source branch type.")
    }
}

$impactChecks = @(
    "Automated tests, builds, and static checks pass.",
    "Schema, save, and release compatibility were checked; migration and rollback are documented when needed.",
    "UI loading, error, cancellation, offline, and input states were checked when applicable.",
    "AI/network changes cover budget, safety, privacy, persistence, and offline fallback when applicable.",
    "External or generated asset sources and rights are recorded when applicable.",
    "README, ROADMAP, GLOSSARY, ADRs, and CHANGELOG were updated when needed."
)
foreach ($impactCheck in $impactChecks) {
    if ($bodyWithoutComments -notmatch "(?m)^- \[[ xX]\] $([regex]::Escape($impactCheck))\s*$") {
        $failures.Add("Impact Check must retain: $impactCheck")
    }
}

$doorMatch = [regex]::Match($bodyWithoutComments, '(?im)^\*\*Door:\*\*\s+(?<value>One-way|Two-way)\s*$')
if (-not $doorMatch.Success) {
    $failures.Add("Merge Danger must classify the change as a One-way or Two-way door.")
}

$blastRadiusMatch = [regex]::Match($bodyWithoutComments, '(?im)^\*\*Blast Radius:\*\*\s+(?<value>\S.*)$')
if (-not $blastRadiusMatch.Success -or -not (Test-ConcreteValue $blastRadiusMatch.Groups['value'].Value)) {
    $failures.Add("Merge Danger must name a non-empty blast radius.")
}

$evidenceMatch = [regex]::Match($bodyWithoutComments, '(?ms)^## Evidence\s*\r?\n(?<content>.*?)(?=^## |\z)')
$beforeMatch = [regex]::Match($evidenceMatch.Groups['content'].Value, '(?im)^\s*-?\s*\*\*Before:\*\*\s*(?<value>\S.*)$')
$afterMatch = [regex]::Match($evidenceMatch.Groups['content'].Value, '(?im)^\s*-?\s*\*\*After:\*\*\s*(?<value>\S.*)$')
if (
    -not $evidenceMatch.Success -or
    -not $beforeMatch.Success -or
    -not (Test-ConcreteValue $beforeMatch.Groups['value'].Value) -or
    -not $afterMatch.Success -or
    -not (Test-ConcreteValue $afterMatch.Groups['value'].Value)
) {
    $failures.Add("Evidence must contain concrete, non-placeholder Before and After results.")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: pull request contract"
