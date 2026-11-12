param(
    [string]$BundlePath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseConfig = Get-Content -LiteralPath (Join-Path $repoRoot "tools\release\windows-export.json") -Encoding UTF8 -Raw | ConvertFrom-Json
$engineVersion = Get-Content -LiteralPath (Join-Path $repoRoot "engine\version.json") -Encoding UTF8 -Raw | ConvertFrom-Json
$windowsArtifacts = Get-Content -LiteralPath (Join-Path $repoRoot "tools\godot\windows-artifacts.json") -Encoding UTF8 -Raw | ConvertFrom-Json
. (Join-Path $repoRoot "tools\release\release_helpers.ps1")
Assert-CineWeaveCleanRepository -RepositoryRoot $repoRoot

if ([string]::IsNullOrWhiteSpace($BundlePath)) {
    $BundlePath = Join-Path $repoRoot "dist\$($releaseConfig.artifact_name)"
}
$BundlePath = [System.IO.Path]::GetFullPath($BundlePath)
if (-not (Test-Path -LiteralPath $BundlePath -PathType Container)) {
    throw "Windows acceptance package was not found: $BundlePath"
}

$expectedFiles = @(
    "BUILD-EVIDENCE.json",
    "CineWeave.exe",
    "CineWeave.pck",
    "README.txt",
    "SHA256SUMS.txt",
    "licenses/CineWeave-MIT.txt",
    "licenses/Godot-MIT.txt",
    "licenses/NotoSansSC-OFL-1.1.txt",
    "licenses/THIRD_PARTY_NOTICES.md",
    "licenses/ZERO_ECHO_RIGHTS.md"
)
$actualFiles = @(
    Get-ChildItem -LiteralPath $BundlePath -Recurse -File |
        ForEach-Object { $_.FullName.Substring($BundlePath.Length).TrimStart('\') -replace '\\', '/' } |
        Sort-Object
)
$fileDifference = @(Compare-Object -ReferenceObject ($expectedFiles | Sort-Object) -DifferenceObject $actualFiles)
if ($fileDifference.Count -gt 0) {
    throw "Windows acceptance package file set is not exact: $($fileDifference | Out-String)"
}

$checksumPath = Join-Path $BundlePath "SHA256SUMS.txt"
$checksumLines = @(Get-Content -LiteralPath $checksumPath -Encoding ASCII | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$expectedChecksummedFiles = @($expectedFiles | Where-Object { $_ -ne "SHA256SUMS.txt" } | Sort-Object)
$checksummedFiles = [System.Collections.Generic.List[string]]::new()
foreach ($line in $checksumLines) {
    if ($line -notmatch '^(?<hash>[0-9a-f]{64})  (?<path>.+)$') {
        throw "Invalid SHA256SUMS line: $line"
    }
    $relativePath = $Matches['path']
    $checksummedFiles.Add($relativePath)
    $filePath = Join-Path $BundlePath ($relativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "SHA256SUMS references a missing file: $relativePath"
    }
    $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $Matches['hash']) {
        throw "SHA-256 mismatch for $relativePath."
    }
}
$checksumDifference = @(Compare-Object -ReferenceObject $expectedChecksummedFiles -DifferenceObject ($checksummedFiles | Sort-Object))
if ($checksumDifference.Count -gt 0) {
    throw "SHA256SUMS does not cover the exact package file set."
}

$evidencePath = Join-Path $BundlePath "BUILD-EVIDENCE.json"
$evidence = Get-Content -LiteralPath $evidencePath -Encoding UTF8 -Raw | ConvertFrom-Json
if (
    $evidence.schema_version -ne 1 -or
    $evidence.product_version -ne $releaseConfig.product_version -or
    $evidence.artifact_name -ne $releaseConfig.artifact_name -or
    $evidence.engine_source_commit -ne $engineVersion.source_commit -or
    $evidence.official_windows_console_sha256 -ne $windowsArtifacts.official_windows_console_sha256 -or
    $evidence.official_windows_executable_sha256 -ne $windowsArtifacts.official_windows_executable_sha256 -or
    $evidence.windows_release_template_sha256 -ne $windowsArtifacts.windows_release_template_sha256 -or
    $evidence.architecture -ne "x86_64" -or
    $evidence.offline_runtime -ne $true
) {
    throw "BUILD-EVIDENCE.json does not identify the approved V0.1 Windows artifact."
}

$executablePath = Join-Path $BundlePath $releaseConfig.executable_name
$packagePath = Join-Path $BundlePath $releaseConfig.package_name
if ((Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $evidence.executable_sha256) {
    throw "BUILD-EVIDENCE.json executable hash does not match."
}
if ((Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $evidence.package_sha256) {
    throw "BUILD-EVIDENCE.json package hash does not match."
}
$sourceStoryPack = Join-Path $repoRoot "content\samples\zero-echo\storypack.json"
if ((Get-FileHash -LiteralPath $sourceStoryPack -Algorithm SHA256).Hash.ToLowerInvariant() -ne $evidence.storypack_sha256) {
    throw "BUILD-EVIDENCE.json StoryPack hash does not match the authoritative V0.1 content."
}
if ($evidence.source_commit -notmatch '^[0-9a-f]{40}$') {
    throw "BUILD-EVIDENCE.json must pin a complete source commit."
}
$currentCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentCommit -ne $evidence.source_commit) {
    throw "BUILD-EVIDENCE.json does not match the current clean source commit. Re-export this artifact."
}

$rightsCopies = @(
    @{ Source = "LICENSE"; Bundle = "licenses\CineWeave-MIT.txt" },
    @{ Source = "engine\godot\LICENSE.txt"; Bundle = "licenses\Godot-MIT.txt" },
    @{ Source = "licenses\NotoSansSC-OFL-1.1.txt"; Bundle = "licenses\NotoSansSC-OFL-1.1.txt" },
    @{ Source = "THIRD_PARTY_NOTICES.md"; Bundle = "licenses\THIRD_PARTY_NOTICES.md" },
    @{ Source = "content\samples\zero-echo\ASSET_SOURCE.md"; Bundle = "licenses\ZERO_ECHO_RIGHTS.md" },
    @{ Source = "docs\release\V0.1-BUNDLE-README.txt"; Bundle = "README.txt" }
)
foreach ($rightsCopy in $rightsCopies) {
    $sourcePath = Join-Path $repoRoot $rightsCopy.Source
    $bundleCopyPath = Join-Path $BundlePath $rightsCopy.Bundle
    if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $bundleCopyPath -Algorithm SHA256).Hash) {
        throw "Bundled rights or release text differs from its authoritative source: $($rightsCopy.Bundle)"
    }
}

$stream = [System.IO.File]::OpenRead($executablePath)
try {
    $reader = [System.IO.BinaryReader]::new($stream)
    if ($reader.ReadUInt16() -ne 0x5A4D) {
        throw "CineWeave.exe is not a Windows PE executable."
    }
    $stream.Position = 0x3C
    $peOffset = $reader.ReadInt32()
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) {
        throw "CineWeave.exe has an invalid PE header."
    }
    if ($reader.ReadUInt16() -ne 0x8664) {
        throw "CineWeave.exe is not an x86_64 Windows executable."
    }
}
finally {
    if ($null -ne $reader) {
        $reader.Dispose()
    }
    $stream.Dispose()
}

$packageStream = [System.IO.File]::OpenRead($packagePath)
try {
    $packageHeader = New-Object byte[] 4
    if ($packageStream.Read($packageHeader, 0, 4) -ne 4 -or [System.Text.Encoding]::ASCII.GetString($packageHeader) -ne "GDPC") {
        throw "CineWeave.pck does not have a Godot package header."
    }
}
finally {
    $packageStream.Dispose()
}

if ($null -eq (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) -or $null -eq (Get-Command Get-NetUDPEndpoint -ErrorAction SilentlyContinue)) {
    throw "Windows network observation commands are unavailable."
}

$observedNetwork = [System.Collections.Generic.List[string]]::new()
$process = $null
$observationSeconds = 10
try {
    $process = Start-Process -FilePath $executablePath `
        -WorkingDirectory $BundlePath `
        -WindowStyle Hidden `
        -PassThru

    $deadline = [DateTime]::UtcNow.AddSeconds($observationSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $process.Refresh()
        if ($process.HasExited) {
            $process.WaitForExit()
            throw "Exported CineWeave GUI exited during the ${observationSeconds}-second startup observation (exit code $($process.ExitCode))."
        }
        @(Get-NetTCPConnection -OwningProcess $process.Id -ErrorAction SilentlyContinue) |
            ForEach-Object { $observedNetwork.Add("TCP $($_.LocalAddress):$($_.LocalPort) -> $($_.RemoteAddress):$($_.RemotePort) $($_.State)") }
        @(Get-NetUDPEndpoint -OwningProcess $process.Id -ErrorAction SilentlyContinue) |
            ForEach-Object { $observedNetwork.Add("UDP $($_.LocalAddress):$($_.LocalPort)") }
        Start-Sleep -Milliseconds 100
    }
    if ($observedNetwork.Count -gt 0) {
        throw "Exported CineWeave opened a network endpoint during GUI startup: $($observedNetwork | Select-Object -Unique | Out-String)"
    }
}
finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) {
            $process.Kill()
        }
        $process.WaitForExit()
    }
}

Write-Output "PASS: exported CineWeave Windows package is complete, x86_64, and its GUI stayed runnable and endpoint-free for ${observationSeconds} seconds"
exit 0
