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
