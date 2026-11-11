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

$requiredSections = @("Summary", "GitFlow", "Evidence", "Impact Check", "Merge Danger")
foreach ($section in $requiredSections) {
    if ($body -notmatch "(?m)^## $([regex]::Escape($section))\s*$") {
        $failures.Add("Pull request body must include the '$section' section.")
    }
}

if ($HeadBranch -match '^(feature|bugfix)/') {
    if ($BaseBranch -ne "develop") {
        $failures.Add("Feature and bugfix pull requests must target develop.")
    }
    if ($body -notmatch '(?im)\bRefs\s+#\d+\b') {
        $failures.Add("Feature and bugfix pull requests must reference their Ticket with 'Refs #<issue>'.")
    }
}

if ($body -notmatch '(?im)^\*\*Door:\*\*\s+(One-way|Two-way)\s*$') {
    $failures.Add("Merge Danger must classify the change as a One-way or Two-way door.")
}

if ($body -notmatch '(?im)^\*\*Blast Radius:\*\*\s+\S.+$') {
    $failures.Add("Merge Danger must name a non-empty blast radius.")
}

$evidenceMatch = [regex]::Match($body, '(?ms)^## Evidence\s*\r?\n(?<content>.*?)(?=^## |\z)')
if (-not $evidenceMatch.Success -or $evidenceMatch.Groups['content'].Value.Trim().Length -lt 20) {
    $failures.Add("Evidence must contain concrete before/after or execution results.")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: pull request contract"
