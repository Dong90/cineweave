$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-File {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing Windows export contract file: $RelativePath")
    }
}

$requiredFiles = @(
    "apps\player-godot\export_presets.cfg",
    "tools\godot\resolve_godot.ps1",
    "tools\godot\windows-artifacts.json",
    "tools\release\release_helpers.ps1",
    "tools\release\windows-export.json",
    "tools\release\export_windows.ps1",
    "tests\verify_windows_export.ps1",
    "docs\release\V0.1-WINDOWS.md"
)

foreach ($relativePath in $requiredFiles) {
    Assert-File -RelativePath $relativePath
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

$windowsArtifactsPath = Join-Path $repoRoot "tools\godot\windows-artifacts.json"
$windowsArtifacts = $null
if (Test-Path -LiteralPath $windowsArtifactsPath -PathType Leaf) {
    try {
        $windowsArtifacts = Get-Content -LiteralPath $windowsArtifactsPath -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        $failures.Add("tools/godot/windows-artifacts.json must contain valid JSON.")
    }
}
if ($null -ne $windowsArtifacts -and $null -ne $engineVersion) {
    if ($windowsArtifacts.engine_source_commit -ne $engineVersion.source_commit) {
        $failures.Add("Windows artifact lock must match engine/version.json source_commit.")
    }
    foreach ($sha256Property in @("official_windows_console_sha256", "windows_release_template_sha256")) {
        if ($windowsArtifacts.$sha256Property -notmatch '^[0-9A-Fa-f]{64}$') {
            $failures.Add("Windows artifact lock must pin $sha256Property as SHA-256.")
        }
    }
    if ($windowsArtifacts.export_templates_sha512 -notmatch '^[0-9A-Fa-f]{128}$') {
        $failures.Add("Windows artifact lock must pin export_templates_sha512 as SHA-512.")
    }
    if ($windowsArtifacts.windows_release_template -ne "windows_release_x86_64.exe") {
        $failures.Add("Windows artifact lock must identify the x86_64 Windows release template.")
    }
}

$releaseConfigPath = Join-Path $repoRoot "tools\release\windows-export.json"
if (Test-Path -LiteralPath $releaseConfigPath -PathType Leaf) {
    try {
        $releaseConfig = Get-Content -LiteralPath $releaseConfigPath -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        $failures.Add("tools/release/windows-export.json must contain valid JSON.")
        $releaseConfig = $null
    }

    if ($null -ne $releaseConfig) {
        if ($releaseConfig.schema_version -ne 1) {
            $failures.Add("Windows export config must use schema_version 1.")
        }
        if ($releaseConfig.product_version -ne "0.1.0") {
            $failures.Add("Windows export config must identify CineWeave 0.1.0.")
        }
        if ($releaseConfig.preset -ne "Windows Desktop") {
            $failures.Add("Windows export config must select the Windows Desktop preset.")
        }
        if ($releaseConfig.artifact_name -ne "CineWeave-v0.1.0-windows-x86_64") {
            $failures.Add("Windows export config must use the stable V0.1 artifact name.")
        }
        foreach ($versionCoupledProperty in @(
            "official_windows_console_sha256",
            "export_templates_asset",
            "export_templates_sha512",
            "windows_release_template",
            "windows_release_template_sha256"
        )) {
            if ($null -ne $releaseConfig.PSObject.Properties[$versionCoupledProperty]) {
                $failures.Add("Windows export config must derive $versionCoupledProperty from engine/version.json.")
            }
        }
    }
}

$presetPath = Join-Path $repoRoot "apps\player-godot\export_presets.cfg"
if (Test-Path -LiteralPath $presetPath -PathType Leaf) {
    $preset = Get-Content -LiteralPath $presetPath -Encoding UTF8 -Raw
    $requiredPresetPatterns = @(
        '(?m)^name="Windows Desktop"$',
        '(?m)^platform="Windows Desktop"$',
        '(?m)^runnable=true$',
        '(?m)^export_filter="all_resources"$',
        '(?m)^include_filter="content/\*\*/\*\.json"$',
        '(?m)^exclude_filter="tests/\*\*,content/zero-echo/media/zero-echo\.ogv"$',
        '(?m)^export_path="\.\./\.\./dist/CineWeave-v0\.1\.0-windows-x86_64/CineWeave\.exe"$',
        '(?m)^binary_format/architecture="x86_64"$',
        '(?m)^binary_format/embed_pck=false$',
        '(?m)^application/product_version="0\.1\.0\.0"$',
        '(?m)^application/file_version="0\.1\.0\.0"$'
    )
    foreach ($pattern in $requiredPresetPatterns) {
        if ($preset -notmatch $pattern) {
            $failures.Add("Windows export preset is missing required contract: $pattern")
        }
    }
    if ($preset -match '(?m)^custom_template/(?:debug|release)="[^\"]+"$') {
        $failures.Add("Windows export preset must not depend on a machine-local custom template path.")
    }
}

$trackedReleaseBinaries = @(
    git -C $repoRoot ls-files -- '*.exe' '*.pck' '*.tpz' 'dist/**' 'build/**' |
        Where-Object { $_ -notmatch '^engine/godot/' }
)
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Unable to inspect tracked release binaries.")
}
elseif ($trackedReleaseBinaries.Count -gt 0) {
    $failures.Add("Generated release binaries must remain untracked: $($trackedReleaseBinaries -join ', ')")
}

foreach ($ignoredPath in @("dist/CineWeave.exe", "build/windows/cache.tmp")) {
    git -C $repoRoot check-ignore --quiet -- $ignoredPath
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Generated path must be ignored by Git: $ignoredPath")
    }
}

$productionFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot "apps\player-godot") -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '[\\/]tests[\\/]' -and
            $_.FullName -notmatch '[\\/]\.godot[\\/]' -and
            $_.Extension -in @(".gd", ".tscn", ".tres", ".godot", ".json")
        }
)
$forbiddenRuntimePatterns = @(
    'HTTPRequest',
    'HTTPClient',
    'WebSocketPeer',
    'WebSocketMultiplayerPeer',
    'StreamPeerTCP',
    'PacketPeerUDP',
    'Telemetry',
    'api[_-]?key',
    'access[_-]?token',
    'client[_-]?secret',
    'OPENAI_API_KEY',
    'ANTHROPIC_API_KEY',
    'https?://'
)
foreach ($file in $productionFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Encoding UTF8 -Raw
    foreach ($pattern in $forbiddenRuntimePatterns) {
        if ($source -match $pattern) {
            $relativePath = $file.FullName.Substring($repoRoot.Length).TrimStart('\')
            $failures.Add("V0.1 production input must remain offline; found '$pattern' in $relativePath.")
        }
    }
}

foreach ($scriptRelativePath in @(
    "tools\release\export_windows.ps1",
    "tests\verify_windows_export.ps1",
    "tests\test_windows_export_contract.ps1"
)) {
    $scriptPath = Join-Path $repoRoot $scriptRelativePath
    if (Test-Path -LiteralPath $scriptPath -PathType Leaf) {
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $scriptPath,
            [ref]$null,
            [ref]$parseErrors
        )
        if ($parseErrors.Count -gt 0) {
            $failures.Add("$scriptRelativePath must parse without PowerShell syntax errors.")
        }
    }
}

$scriptInterfaces = @(
    @{ Path = "tools\release\export_windows.ps1"; Forbidden = @("SkipValidation") },
    @{ Path = "tests\verify_windows_export.ps1"; Forbidden = @("SkipRuntimeObservation") }
)
foreach ($interface in $scriptInterfaces) {
    $scriptPath = Join-Path $repoRoot $interface.Path
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        continue
    }
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    $publicParameters = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    foreach ($forbiddenParameter in $interface.Forbidden) {
        if ($publicParameters -contains $forbiddenParameter) {
            $failures.Add("$($interface.Path) must not expose the $forbiddenParameter bypass.")
        }
    }
}

$releaseHelpersPath = Join-Path $repoRoot "tools\release\release_helpers.ps1"
if (Test-Path -LiteralPath $releaseHelpersPath -PathType Leaf) {
    . $releaseHelpersPath
    $fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("cineweave-release-contract-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    try {
        $plainDirectory = Join-Path $fixtureRoot "plain"
        New-Item -ItemType Directory -Path $plainDirectory | Out-Null
        Set-Content -LiteralPath (Join-Path $plainDirectory "marker.txt") -Value "safe" -Encoding ASCII
        Remove-CineWeaveExactDirectory -Path $plainDirectory
        if (Test-Path -LiteralPath $plainDirectory) {
            $failures.Add("Release directory removal must remove an ordinary exact directory.")
        }

        $syntheticRoot = "X:\release-output"
        $syntheticChild = "$syntheticRoot\ordinary"
        $syntheticJunction = "$syntheticChild\nested-junction"
        $syntheticEntries = @{
            $syntheticRoot = @($syntheticChild)
            $syntheticChild = @($syntheticJunction)
        }
        $syntheticAttributes = @{
            $syntheticRoot = [System.IO.FileAttributes]::Directory
            $syntheticChild = [System.IO.FileAttributes]::Directory
            $syntheticJunction = [System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::ReparsePoint
        }
        $syntheticMutation = [pscustomobject]@{ DeleteAttempted = $false }
        $nestedJunctionRejected = $false
        try {
            Remove-CineWeaveExactDirectory `
                -Path $syntheticRoot `
                -DirectoryExists { $true } `
                -GetEntries { param($Path) @($syntheticEntries[$Path]) } `
                -GetAttributes { param($Path) $syntheticAttributes[$Path] } `
                -SetFileNormal { $syntheticMutation.DeleteAttempted = $true } `
                -DeleteFile { $syntheticMutation.DeleteAttempted = $true } `
                -DeleteDirectory { $syntheticMutation.DeleteAttempted = $true }
        }
        catch {
            $nestedJunctionRejected = $true
        }
        if (-not $nestedJunctionRejected -or $syntheticMutation.DeleteAttempted) {
            $failures.Add("Release deletion must reject a nested reparse point before attempting any mutation.")
        }

        $utf8Path = Join-Path $fixtureRoot "utf8.json"
        if ($null -eq (Get-Command ConvertTo-CineWeaveFlatJson -ErrorAction SilentlyContinue)) {
            $failures.Add("Release helpers must provide deterministic flat JSON serialization.")
            $jsonFixture = "{`r`n  `"ok`": true`r`n}"
        }
        else {
            $jsonFixture = ConvertTo-CineWeaveFlatJson -Values ([ordered]@{
                schema_version = 1
                text = "line 1`nline `"2`""
                enabled = $true
            })
            $expectedJsonFixture = "{`n  `"schema_version`": 1,`n  `"text`": `"line 1\nline \`"2\`"`",`n  `"enabled`": true`n}"
            if ($jsonFixture -ne $expectedJsonFixture) {
                $failures.Add("Release JSON serialization must have a fixed cross-PowerShell representation.")
            }
        }
        Write-CineWeaveUtf8NoBom -Path $utf8Path -Content $jsonFixture
        $utf8Bytes = [System.IO.File]::ReadAllBytes($utf8Path)
        if ($utf8Bytes.Length -ge 3 -and $utf8Bytes[0] -eq 0xEF -and $utf8Bytes[1] -eq 0xBB -and $utf8Bytes[2] -eq 0xBF) {
            $failures.Add("Release UTF-8 output must not contain a BOM.")
        }
        if ([System.IO.File]::ReadAllText($utf8Path).Contains("`r")) {
            $failures.Add("Release UTF-8 output must normalize line endings to LF.")
        }

        $gitFixture = Join-Path $fixtureRoot "git"
        New-Item -ItemType Directory -Path $gitFixture | Out-Null
        & git -C $gitFixture init --quiet
        & git -C $gitFixture config user.email "contract@cineweave.invalid"
        & git -C $gitFixture config user.name "CineWeave Contract"
        Set-Content -LiteralPath (Join-Path $gitFixture "tracked.txt") -Value "clean" -Encoding ASCII
        & git -C $gitFixture add tracked.txt
        & git -C $gitFixture commit --quiet -m "fixture"
        Assert-CineWeaveCleanRepository -RepositoryRoot $gitFixture
        Set-Content -LiteralPath (Join-Path $gitFixture "tracked.txt") -Value "dirty" -Encoding ASCII
        $dirtyRejected = $false
        try {
            Assert-CineWeaveCleanRepository -RepositoryRoot $gitFixture
        }
        catch {
            $dirtyRejected = $true
        }
        if (-not $dirtyRejected) {
            $failures.Add("Release export must reject a dirty source repository.")
        }
    }
    finally {
        if (Test-Path -LiteralPath $fixtureRoot) {
            Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
        }
    }
}

$releaseGuidePath = Join-Path $repoRoot "docs\release\V0.1-WINDOWS.md"
if (Test-Path -LiteralPath $releaseGuidePath -PathType Leaf) {
    $releaseGuide = Get-Content -LiteralPath $releaseGuidePath -Encoding UTF8 -Raw
    foreach ($requiredText in @(
        "submodule update --init --depth 1 engine/godot",
        "sync_storypacks.ps1 -Check",
        "run_headless.ps1",
        "export_windows.ps1",
        "verify_windows_export.ps1",
        "Known limitations",
        "V0.2"
    )) {
        if (-not $releaseGuide.Contains($requiredText)) {
            $failures.Add("V0.1 Windows release guide must include '$requiredText'.")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: Windows export contract regression tests"
exit 0
