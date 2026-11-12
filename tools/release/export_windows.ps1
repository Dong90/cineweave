param(
    [string]$GodotPath = $env:GODOT_BIN,
    [string]$OutputRoot,
    [switch]$Bootstrap,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$projectPath = Join-Path $repoRoot "apps\player-godot"
$engineVersionPath = Join-Path $repoRoot "engine\version.json"
$windowsArtifactsPath = Join-Path $repoRoot "tools\godot\windows-artifacts.json"
$releaseConfigPath = Join-Path $PSScriptRoot "windows-export.json"
$shellExecutable = (Get-Process -Id $PID).Path
. (Join-Path $repoRoot "tools\godot\resolve_godot.ps1")
. (Join-Path $PSScriptRoot "release_helpers.ps1")

function Read-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label was not found: $Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        throw "$Label is invalid JSON: $Path"
    }
}

function Invoke-Download {
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $destinationDirectory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
    $partialPath = "$Destination.partial"
    if (Test-Path -LiteralPath $partialPath) {
        Remove-Item -LiteralPath $partialPath -Force
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -ne $curl) {
        & $curl.Source --fail --location --retry 3 --silent --show-error --output $partialPath $Uri
        if ($LASTEXITCODE -ne 0) {
            throw "Download failed: $Uri"
        }
    }
    else {
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $partialPath
    }

    Move-Item -LiteralPath $partialPath -Destination $Destination -Force
}

function Assert-FileHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [ValidateSet("SHA256", "SHA512")]
        [string]$Algorithm,
        [Parameter(Mandatory)]
        [string]$Expected
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash
    if ($actual -ne $Expected) {
        throw "$Algorithm mismatch for $Path. Expected $Expected, got $actual."
    }
    return $true
}

function Install-OfficialGodot {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$EngineVersion
    )

    $cacheRoot = Join-Path $env:LOCALAPPDATA "CineWeave\cache\godot\$($EngineVersion.godot_version)"
    $installRoot = Join-Path $env:LOCALAPPDATA "CineWeave\tools\godot\$($EngineVersion.godot_version)"
    $archivePath = Join-Path $cacheRoot "official-windows.zip"
    $consolePath = Join-Path $installRoot $EngineVersion.official_windows_console_executable

    if (Test-Path -LiteralPath $consolePath -PathType Leaf) {
        return $consolePath
    }

    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        Write-Host "Downloading verified official Godot $($EngineVersion.godot_version)..."
        Invoke-Download -Uri $EngineVersion.official_windows_archive_url -Destination $archivePath
    }
    [void](Assert-FileHash -Path $archivePath -Algorithm SHA256 -Expected $EngineVersion.official_windows_archive_sha256)

    $temporaryInstall = "$installRoot.installing"
    if (Test-Path -LiteralPath $temporaryInstall) {
        Remove-CineWeaveExactDirectory -Path $temporaryInstall
    }
    New-Item -ItemType Directory -Force -Path $temporaryInstall | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $temporaryInstall -Force
    if (-not (Test-Path -LiteralPath (Join-Path $temporaryInstall $EngineVersion.official_windows_console_executable))) {
        throw "The verified Godot archive did not contain the expected console executable."
    }
    if (Test-Path -LiteralPath $installRoot) {
        Remove-CineWeaveExactDirectory -Path $installRoot
    }
    Move-Item -LiteralPath $temporaryInstall -Destination $installRoot
    return $consolePath
}

function Install-WindowsExportTemplate {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$EngineVersion,
        [Parameter(Mandatory)]
        [pscustomobject]$WindowsArtifacts
    )

    $templateVersion = $EngineVersion.official_release -replace '-', '.'
    $templateRoot = Join-Path $env:APPDATA "Godot\export_templates\$templateVersion"
    $templatePath = Join-Path $templateRoot $WindowsArtifacts.windows_release_template
    if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
        [void](Assert-FileHash -Path $templatePath -Algorithm SHA256 -Expected $WindowsArtifacts.windows_release_template_sha256)
        return $templatePath
    }

    $cacheRoot = Join-Path $env:LOCALAPPDATA "CineWeave\cache\godot\$($EngineVersion.godot_version)"
    $templateAsset = "Godot_v$($EngineVersion.official_release)_export_templates.tpz"
    $archivePath = Join-Path $cacheRoot $templateAsset
    $archiveUri = "https://github.com/godotengine/godot/releases/download/$($EngineVersion.official_release)/$templateAsset"
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        Write-Host "Downloading official Godot export templates (about 1.2 GB, cached outside the repository)..."
        Invoke-Download -Uri $archiveUri -Destination $archivePath
    }
    [void](Assert-FileHash -Path $archivePath -Algorithm SHA512 -Expected $WindowsArtifacts.export_templates_sha512)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $templateRoot | Out-Null
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entryName = "templates/$($WindowsArtifacts.windows_release_template)"
        $entry = $archive.Entries | Where-Object { $_.FullName -eq $entryName } | Select-Object -First 1
        if ($null -eq $entry) {
            throw "Official template archive does not contain $entryName."
        }
        $temporaryTemplate = "$templatePath.installing"
        if (Test-Path -LiteralPath $temporaryTemplate) {
            Remove-Item -LiteralPath $temporaryTemplate -Force
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $temporaryTemplate, $true)
        Move-Item -LiteralPath $temporaryTemplate -Destination $templatePath -Force
        [void](Assert-FileHash -Path $templatePath -Algorithm SHA256 -Expected $WindowsArtifacts.windows_release_template_sha256)

        $versionEntry = $archive.Entries | Where-Object { $_.FullName -eq "templates/version.txt" } | Select-Object -First 1
        if ($null -ne $versionEntry) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
                $versionEntry,
                (Join-Path $templateRoot "version.txt"),
                $true
            )
        }
    }
    finally {
        $archive.Dispose()
    }
    return $templatePath
}

function Invoke-RepositoryScript {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,
        [string[]]$Arguments = @()
    )

    $scriptPath = Join-Path $repoRoot $RelativePath
    & $shellExecutable -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Repository validation failed: $RelativePath"
    }
}

$engineVersion = Read-JsonFile -Path $engineVersionPath -Label "Engine version manifest"
$windowsArtifacts = Read-JsonFile -Path $windowsArtifactsPath -Label "Windows Godot artifact lock"
$releaseConfig = Read-JsonFile -Path $releaseConfigPath -Label "Windows export config"
if ($windowsArtifacts.engine_source_commit -ne $engineVersion.source_commit) {
    throw "Windows Godot artifact lock does not match engine/version.json."
}
Assert-CineWeaveCleanRepository -RepositoryRoot $repoRoot

$GodotPath = Resolve-CineWeaveGodot -GodotPath $GodotPath -EngineVersion $engineVersion -AllowMissing

if ([string]::IsNullOrWhiteSpace($GodotPath) -and $Bootstrap) {
    $GodotPath = Install-OfficialGodot -EngineVersion $engineVersion
}

try {
    $GodotPath = Resolve-CineWeaveGodot -GodotPath $GodotPath -EngineVersion $engineVersion
}
catch {
    throw "Godot $($engineVersion.godot_version) was not found. Pass -GodotPath, set GODOT_BIN, or use -Bootstrap."
}

$versionOutput = ((& $GodotPath --version 2>&1) -join "`n").Trim()
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "^$([regex]::Escape($engineVersion.godot_version))\.stable(?:\.|$)") {
    throw "Expected official-compatible Godot $($engineVersion.godot_version).stable, got '$versionOutput'."
}
[void](Assert-FileHash -Path $GodotPath -Algorithm SHA256 -Expected $windowsArtifacts.official_windows_console_sha256)

$templateVersion = $engineVersion.official_release -replace '-', '.'
$templatePath = Join-Path $env:APPDATA (
    "Godot\export_templates\{0}\{1}" -f $templateVersion, $windowsArtifacts.windows_release_template
)
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf) -and $Bootstrap) {
    $templatePath = Install-WindowsExportTemplate -EngineVersion $engineVersion -WindowsArtifacts $windowsArtifacts
}
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "Official Windows export template is missing: $templatePath. Re-run with -Bootstrap."
}

Invoke-RepositoryScript -RelativePath "tools\content\sync_storypacks.ps1" -Arguments @("-Check")
Invoke-RepositoryScript -RelativePath "tests\verify_repository.ps1"
Invoke-RepositoryScript -RelativePath "tests\run_headless.ps1" -Arguments @("-GodotPath", $GodotPath)

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot "dist\$($releaseConfig.artifact_name)"
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$repositoryPath = [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
$projectFullPath = [System.IO.Path]::GetFullPath($projectPath).TrimEnd('\')
$driveRoot = [System.IO.Path]::GetPathRoot($OutputRoot).TrimEnd('\')
$outputDirectoryName = Split-Path -Leaf $OutputRoot.TrimEnd('\')
if (
    $OutputRoot.TrimEnd('\') -in @($repositoryPath, $projectFullPath, $driveRoot) -or
    $OutputRoot.StartsWith("$projectFullPath\", [System.StringComparison]::OrdinalIgnoreCase) -or
    $repositoryPath.StartsWith("$($OutputRoot.TrimEnd('\'))\", [System.StringComparison]::OrdinalIgnoreCase) -or
    $outputDirectoryName -ne $releaseConfig.artifact_name
) {
    throw "Unsafe Windows export output path: $OutputRoot"
}
if (Test-Path -LiteralPath $OutputRoot) {
    if (-not $Force) {
        throw "Windows export output already exists: $OutputRoot. Use -Force to replace this exact directory."
    }
    Remove-CineWeaveExactDirectory -Path $OutputRoot
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$executablePath = Join-Path $OutputRoot $releaseConfig.executable_name
Write-Output "Exporting CineWeave $($releaseConfig.product_version) to $OutputRoot"
& $GodotPath --headless --path $projectPath --export-release $releaseConfig.preset $executablePath
if ($LASTEXITCODE -ne 0) {
    throw "Godot Windows export failed."
}

$packagePath = Join-Path $OutputRoot $releaseConfig.package_name
foreach ($requiredArtifact in @($executablePath, $packagePath)) {
    if (-not (Test-Path -LiteralPath $requiredArtifact -PathType Leaf)) {
        throw "Godot export did not produce the expected artifact: $requiredArtifact"
    }
}

Copy-Item -LiteralPath (Join-Path $repoRoot "docs\release\V0.1-BUNDLE-README.txt") -Destination (Join-Path $OutputRoot "README.txt")
$licenseRoot = Join-Path $OutputRoot "licenses"
New-Item -ItemType Directory -Force -Path $licenseRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot "LICENSE") -Destination (Join-Path $licenseRoot "CineWeave-MIT.txt")
Copy-Item -LiteralPath (Join-Path $repoRoot "engine\godot\LICENSE.txt") -Destination (Join-Path $licenseRoot "Godot-MIT.txt")
Copy-Item -LiteralPath (Join-Path $repoRoot "licenses\NotoSansSC-OFL-1.1.txt") -Destination (Join-Path $licenseRoot "NotoSansSC-OFL-1.1.txt")
Copy-Item -LiteralPath (Join-Path $repoRoot "THIRD_PARTY_NOTICES.md") -Destination (Join-Path $licenseRoot "THIRD_PARTY_NOTICES.md")
Copy-Item -LiteralPath (Join-Path $repoRoot "content\samples\zero-echo\ASSET_SOURCE.md") -Destination (Join-Path $licenseRoot "ZERO_ECHO_RIGHTS.md")

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Unable to identify the source commit."
}
$storyPackPath = Join-Path $repoRoot "content\samples\zero-echo\storypack.json"
$evidence = [ordered]@{
    schema_version = 1
    product_version = $releaseConfig.product_version
    artifact_name = $releaseConfig.artifact_name
    source_commit = $sourceCommit
    godot_version = $versionOutput
    official_windows_console_sha256 = (Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash.ToLowerInvariant()
    engine_source_commit = $engineVersion.source_commit
    windows_release_template_sha256 = (Get-FileHash -LiteralPath $templatePath -Algorithm SHA256).Hash.ToLowerInvariant()
    export_preset = $releaseConfig.preset
    architecture = "x86_64"
    offline_runtime = $true
    storypack_sha256 = (Get-FileHash -LiteralPath $storyPackPath -Algorithm SHA256).Hash.ToLowerInvariant()
    executable_sha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash.ToLowerInvariant()
    package_sha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$evidenceJson = ConvertTo-CineWeaveFlatJson -Values $evidence
Write-CineWeaveUtf8NoBom -Path (Join-Path $OutputRoot "BUILD-EVIDENCE.json") -Content $evidenceJson

$checksumPath = Join-Path $OutputRoot "SHA256SUMS.txt"
$checksumLines = @(
    Get-ChildItem -LiteralPath $OutputRoot -Recurse -File |
        Where-Object { $_.FullName -ne $checksumPath } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($OutputRoot.Length).TrimStart('\') -replace '\\', '/'
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relative"
        }
)
$checksumLines | Set-Content -LiteralPath $checksumPath -Encoding ASCII

$verifyArguments = @("-BundlePath", $OutputRoot)
Invoke-RepositoryScript -RelativePath "tests\verify_windows_export.ps1" -Arguments $verifyArguments

Write-Output "PASS: CineWeave Windows offline acceptance package exported and verified"
Write-Output $OutputRoot
exit 0
