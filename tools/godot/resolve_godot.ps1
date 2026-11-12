function Resolve-CineWeaveGodot {
    param(
        [AllowEmptyString()]
        [string]$GodotPath,
        [Parameter(Mandatory)]
        [pscustomobject]$EngineVersion,
        [switch]$AllowMissing
    )

    if ([string]::IsNullOrWhiteSpace($GodotPath)) {
        $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $godotCommand) {
            $GodotPath = $godotCommand.Source
        }
    }

    if ([string]::IsNullOrWhiteSpace($GodotPath)) {
        $managedGodot = Join-Path $env:LOCALAPPDATA (
            "CineWeave\tools\godot\{0}\{1}" -f `
                $EngineVersion.godot_version,
                $EngineVersion.official_windows_console_executable
        )
        if (Test-Path -LiteralPath $managedGodot -PathType Leaf) {
            $GodotPath = $managedGodot
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        $consoleGodot = $GodotPath -replace "\.exe$", "_console.exe"
        if ($GodotPath -notmatch "_console\.exe$" -and (Test-Path -LiteralPath $consoleGodot -PathType Leaf)) {
            $GodotPath = $consoleGodot
        }
    }

    if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        if ($AllowMissing) {
            return $null
        }
        throw "Godot $($EngineVersion.godot_version) was not found. Pass -GodotPath or set GODOT_BIN."
    }

    return [System.IO.Path]::GetFullPath($GodotPath)
}

function Resolve-CineWeaveOfficialGodotPair {
    param(
        [Parameter(Mandatory)]
        [string]$ConsolePath,
        [Parameter(Mandatory)]
        [pscustomobject]$EngineVersion,
        [Parameter(Mandatory)]
        [pscustomobject]$WindowsArtifacts
    )

    $resolvedConsolePath = [System.IO.Path]::GetFullPath($ConsolePath)
    if (-not (Test-Path -LiteralPath $resolvedConsolePath -PathType Leaf)) {
        throw "Official Godot console executable was not found: $resolvedConsolePath"
    }
    if ((Split-Path -Leaf $resolvedConsolePath) -ne $EngineVersion.official_windows_console_executable) {
        throw "Expected the official Godot console executable '$($EngineVersion.official_windows_console_executable)'."
    }

    $resolvedExecutablePath = Join-Path `
        (Split-Path -Parent $resolvedConsolePath) `
        $EngineVersion.official_windows_executable
    if (-not (Test-Path -LiteralPath $resolvedExecutablePath -PathType Leaf)) {
        throw "Official Godot GUI executable was not found beside the console launcher: $resolvedExecutablePath"
    }

    $consoleHash = (Get-FileHash -LiteralPath $resolvedConsolePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $executableHash = (Get-FileHash -LiteralPath $resolvedExecutablePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($consoleHash -ne $WindowsArtifacts.official_windows_console_sha256.ToLowerInvariant()) {
        throw "SHA256 mismatch for the official Godot console executable."
    }
    if ($executableHash -ne $WindowsArtifacts.official_windows_executable_sha256.ToLowerInvariant()) {
        throw "SHA256 mismatch for the official Godot GUI executable."
    }

    return [pscustomobject]@{
        ConsolePath = $resolvedConsolePath
        ExecutablePath = $resolvedExecutablePath
        ConsoleSha256 = $consoleHash
        ExecutableSha256 = $executableHash
    }
}

function Resolve-CineWeaveForkGodotPair {
    param(
        [Parameter(Mandatory)]
        [string]$ConsolePath,
        [Parameter(Mandatory)]
        [string]$VersionOutput,
        [Parameter(Mandatory)]
        [string]$SubmoduleCommit,
        [Parameter(Mandatory)]
        [pscustomobject]$EngineVersion,
        [Parameter(Mandatory)]
        [pscustomobject]$ForkArtifacts
    )

    $resolvedConsolePath = [System.IO.Path]::GetFullPath($ConsolePath)
    if (-not (Test-Path -LiteralPath $resolvedConsolePath -PathType Leaf)) {
        throw "Pinned Fork console executable was not found: $resolvedConsolePath"
    }
    if ((Split-Path -Leaf $resolvedConsolePath) -ne $ForkArtifacts.console_executable) {
        throw "Expected the pinned Fork console executable '$($ForkArtifacts.console_executable)'."
    }

    $resolvedExecutablePath = Join-Path (Split-Path -Parent $resolvedConsolePath) $ForkArtifacts.executable
    if (-not (Test-Path -LiteralPath $resolvedExecutablePath -PathType Leaf)) {
        throw "Pinned Fork GUI executable was not found beside the console launcher: $resolvedExecutablePath"
    }

    $expectedCommit = $EngineVersion.source_commit.ToLowerInvariant()
    if ($SubmoduleCommit.ToLowerInvariant() -ne $expectedCommit) {
        throw "Fork Submodule commit does not match engine/version.json."
    }
    $expectedVersion = "^{0}\.stable\.custom_build\.(?<commit>[0-9a-f]{{8,40}})(?:\.|$)" -f `
        [regex]::Escape($EngineVersion.godot_version)
    if (
        $VersionOutput.Trim() -notmatch $expectedVersion -or
        -not $expectedCommit.StartsWith($Matches['commit'], [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "Fork version output does not identify the pinned source commit: '$VersionOutput'."
    }

    $consoleHash = (Get-FileHash -LiteralPath $resolvedConsolePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $executableHash = (Get-FileHash -LiteralPath $resolvedExecutablePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($consoleHash -ne $ForkArtifacts.console_sha256.ToLowerInvariant()) {
        throw "SHA256 mismatch for the pinned Fork console executable."
    }
    if ($executableHash -ne $ForkArtifacts.executable_sha256.ToLowerInvariant()) {
        throw "SHA256 mismatch for the pinned Fork GUI executable."
    }

    return [pscustomobject]@{
        ConsolePath = $resolvedConsolePath
        ExecutablePath = $resolvedExecutablePath
        ConsoleSha256 = $consoleHash
        ExecutableSha256 = $executableHash
        Version = $VersionOutput.Trim()
        SourceCommit = $expectedCommit
    }
}
