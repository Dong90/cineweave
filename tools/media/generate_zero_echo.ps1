[CmdletBinding()]
param(
    [string]$FfmpegPath = "ffmpeg"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputPath = Join-Path $repoRoot "content\samples\zero-echo\media\zero-echo.ogv"
$outputDirectory = Split-Path -Parent $outputPath
[void](New-Item -ItemType Directory -Path $outputDirectory -Force)

$videoSource = "color=c=0x06131f:s=640x360:d=3:r=24"
$audioSource = "sine=frequency=110:duration=3:sample_rate=48000"
$videoFilter = @(
    "drawgrid=width=64:height=64:color=0x3ba6aa@0.12:thickness=1",
    "drawbox=x=80:y=70:w=480:h=220:color=0x10283a@0.78:t=fill",
    "drawbox=x=80:y=70:w=480:h=220:color=0x3ba6aa@0.55:t=2",
    "drawbox=x='mod(t*180\,720)-80':y=178:w=80:h=3:color=0xe89936@0.95:t=fill",
    "fade=t=in:st=0:d=0.3",
    "fade=t=out:st=2.6:d=0.4"
) -join ","
$audioFilter = "volume=0.025,afade=t=in:st=0:d=0.25,afade=t=out:st=2.5:d=0.5"

& $FfmpegPath -hide_banner -loglevel error -y `
    -f lavfi -i $videoSource `
    -f lavfi -i $audioSource `
    -vf $videoFilter `
    -af $audioFilter `
    -map_metadata -1 `
    -fflags +bitexact `
    -flags:v +bitexact -c:v libtheora -q:v 5 -pix_fmt yuv420p -g 48 `
    -flags:a +bitexact -c:a libvorbis -q:a 2 `
    -serial_offset 1729 `
    -shortest $outputPath
if ($LASTEXITCODE -ne 0) {
    throw "FFmpeg failed to generate the zero-echo test clip."
}

& (Join-Path $repoRoot "tools\content\sync_storypacks.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "StoryPack synchronization failed after media generation."
}

$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
Write-Output "Generated $outputPath"
Write-Output "SHA256 $hash"
