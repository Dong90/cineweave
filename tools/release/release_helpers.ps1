function Assert-CineWeaveCleanRepository {
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $status = @(& git -C $RepositoryRoot status --porcelain=v1 --untracked-files=all 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect release source repository status: $($status -join [Environment]::NewLine)"
    }
    if ($status.Count -gt 0) {
        throw "Release export requires a clean source repository. Commit or remove these changes:$([Environment]::NewLine)$($status -join [Environment]::NewLine)"
    }
}

function Test-CineWeaveReparsePoint {
    param(
        [Parameter(Mandatory)]
        [System.IO.FileAttributes]$Attributes
    )

    return ($Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}

function Get-CineWeaveSafeDirectoryTree {
    param(
        [Parameter(Mandatory)]
        [string]$RootPath,
        [scriptblock]$GetAttributes = { param($Path) [System.IO.File]::GetAttributes($Path) },
        [scriptblock]$GetEntries = { param($Path) @([System.IO.Directory]::EnumerateFileSystemEntries($Path)) }
    )

    $directories = [System.Collections.Generic.List[string]]::new()
    $files = [System.Collections.Generic.List[string]]::new()
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($RootPath)

    while ($pending.Count -gt 0) {
        $currentDirectory = $pending.Pop()
        $currentAttributes = & $GetAttributes $currentDirectory
        if (Test-CineWeaveReparsePoint -Attributes $currentAttributes) {
            throw "Refusing to remove a directory tree containing a reparse point: $currentDirectory"
        }
        $directories.Add($currentDirectory)

        foreach ($entryPath in @(& $GetEntries $currentDirectory)) {
            $entryAttributes = & $GetAttributes $entryPath
            if (Test-CineWeaveReparsePoint -Attributes $entryAttributes) {
                throw "Refusing to remove a directory tree containing a reparse point: $entryPath"
            }
            if (($entryAttributes -band [System.IO.FileAttributes]::Directory) -ne 0) {
                $pending.Push($entryPath)
            }
            else {
                $files.Add($entryPath)
            }
        }
    }

    return [pscustomobject]@{
        Directories = $directories
        Files = $files
    }
}

function Remove-CineWeaveExactDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [scriptblock]$DirectoryExists = { param($CandidatePath) Test-Path -LiteralPath $CandidatePath -PathType Container },
        [scriptblock]$GetAttributes = { param($CandidatePath) [System.IO.File]::GetAttributes($CandidatePath) },
        [scriptblock]$GetEntries = { param($CandidatePath) @([System.IO.Directory]::EnumerateFileSystemEntries($CandidatePath)) },
        [scriptblock]$SetFileNormal = { param($CandidatePath) [System.IO.File]::SetAttributes($CandidatePath, [System.IO.FileAttributes]::Normal) },
        [scriptblock]$DeleteFile = { param($CandidatePath) [System.IO.File]::Delete($CandidatePath) },
        [scriptblock]$DeleteDirectory = { param($CandidatePath) [System.IO.Directory]::Delete($CandidatePath, $false) }
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $driveRoot = [System.IO.Path]::GetPathRoot($fullPath).TrimEnd('\')
    if ($fullPath -eq $driveRoot) {
        throw "Refusing to remove a drive root: $fullPath"
    }
    if (-not (& $DirectoryExists $fullPath)) {
        throw "Exact release directory does not exist: $fullPath"
    }

    $tree = Get-CineWeaveSafeDirectoryTree `
        -RootPath $fullPath `
        -GetAttributes $GetAttributes `
        -GetEntries $GetEntries

    foreach ($filePath in $tree.Files) {
        $fileAttributes = & $GetAttributes $filePath
        if (Test-CineWeaveReparsePoint -Attributes $fileAttributes) {
            throw "Refusing to remove a file that became a reparse point: $filePath"
        }
        & $SetFileNormal $filePath
        & $DeleteFile $filePath
    }

    foreach ($directoryPath in @($tree.Directories | Sort-Object { $_.Length } -Descending)) {
        $directoryAttributes = & $GetAttributes $directoryPath
        if (Test-CineWeaveReparsePoint -Attributes $directoryAttributes) {
            throw "Refusing to remove a directory that became a reparse point: $directoryPath"
        }
        & $DeleteDirectory $directoryPath
    }
}

function ConvertTo-CineWeaveJsonString {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $builder = [System.Text.StringBuilder]::new()
    foreach ($character in $Value.ToCharArray()) {
        switch ($character) {
            '"' { [void]$builder.Append('\"') }
            '\' { [void]$builder.Append('\\') }
            "`b" { [void]$builder.Append('\b') }
            "`t" { [void]$builder.Append('\t') }
            "`n" { [void]$builder.Append('\n') }
            "`f" { [void]$builder.Append('\f') }
            "`r" { [void]$builder.Append('\r') }
            default {
                $codePoint = [int]$character
                if ($codePoint -lt 0x20) {
                    [void]$builder.Append(('\u{0:x4}' -f $codePoint))
                }
                else {
                    [void]$builder.Append($character)
                }
            }
        }
    }
    return $builder.ToString()
}

function ConvertTo-CineWeaveFlatJson {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Values
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("{")
    $keys = @($Values.Keys)
    for ($index = 0; $index -lt $keys.Count; $index++) {
        $key = [string]$keys[$index]
        $value = $Values[$key]
        if ($null -eq $value) {
            $encodedValue = "null"
        }
        elseif ($value -is [bool]) {
            $encodedValue = if ($value) { "true" } else { "false" }
        }
        elseif ($value -is [string]) {
            $encodedValue = '"' + (ConvertTo-CineWeaveJsonString -Value $value) + '"'
        }
        elseif ($value -is [System.ValueType]) {
            $encodedValue = [System.Convert]::ToString($value, [System.Globalization.CultureInfo]::InvariantCulture)
        }
        else {
            throw "Unsupported deterministic JSON value for '$key': $($value.GetType().FullName)"
        }

        $comma = if ($index -lt $keys.Count - 1) { "," } else { "" }
        $encodedKey = ConvertTo-CineWeaveJsonString -Value $key
        $lines.Add("  `"$encodedKey`": $encodedValue$comma")
    }
    $lines.Add("}")
    return $lines -join "`n"
}

function Write-CineWeaveUtf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Content
    )

    $normalized = (($Content -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd("`n") + "`n"
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($Path), $normalized, $encoding)
}
