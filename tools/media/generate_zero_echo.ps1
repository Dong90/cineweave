[CmdletBinding()]
param(
    [string]$FfmpegPath = "ffmpeg",
    [string]$FfprobePath = "ffprobe"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputDirectory = Join-Path $repoRoot "content\samples\zero-echo\media"
$manifestPath = Join-Path $outputDirectory "media-manifest.json"
[void](New-Item -ItemType Directory -Path $outputDirectory -Force)

$clips = @(
    [ordered]@{
        Name = "platform-2357"
        Duration = 50
        Serial = 1730
        NoiseSeed = 2357
        Tone = 42
        Visual = "drawbox=x=0:y=420:w=1280:h=300:color=0x071018@0.96:t=fill,drawbox=x=0:y=468:w=1280:h=8:color=0x203844@0.75:t=fill,drawbox=x=0:y=550:w=1280:h=5:color=0x203844@0.58:t=fill,drawbox=x='mod(t*42\,1180)+50':y=386:w=74:h=3:color=0xd4933b@0.9:t=fill"
    },
    [ordered]@{
        Name = "future-warning"
        Duration = 60
        Serial = 1731
        NoiseSeed = 1
        Tone = 58
        Visual = "drawbox=x=420:y=70:w=440:h=580:color=0x05090f@0.92:t=fill,drawbox=x=420:y=70:w=440:h=580:color=0x3ba6aa@0.48:t=3,drawbox=x=470:y=190:w=340:h=72:color=0x173340@0.9:t=fill,drawbox=x=470:y=290:w=280:h=52:color=0x173340@0.62:t=fill,drawbox=x=470:y=370:w=320:h=52:color=0x173340@0.62:t=fill,drawbox=x='470+mod(t*32\,320)':y=470:w=4:h=90:color=0xd4933b@0.7:t=fill"
    },
    [ordered]@{
        Name = "midnight-train-arrives"
        Duration = 55
        Serial = 1732
        NoiseSeed = 2
        Tone = 54
        Visual = "drawbox=x=0:y=430:w=1280:h=290:color=0x050b12@0.98:t=fill,drawbox=x=0:y=500:w=1280:h=7:color=0x29414b@0.8:t=fill,drawbox=x='1280-mod(t*46\,1540)':y=210:w=900:h=285:color=0x0b1b27@0.98:t=fill,drawbox=x='1330-mod(t*46\,1540)':y=260:w=128:h=88:color=0x9bc4bd@0.22:t=fill,drawbox=x='1500-mod(t*46\,1540)':y=260:w=128:h=88:color=0x9bc4bd@0.22:t=fill,drawbox=x='1668-mod(t*46\,1540)':y=260:w=128:h=88:color=0x9bc4bd@0.22:t=fill"
    },
    [ordered]@{
        Name = "board-loop-reveal"
        Duration = 70
        Serial = 1733
        NoiseSeed = 19
        Tone = 48
        Visual = "drawbox=x=0:y=135:w=1280:h=450:color=0x04080d@0.9:t=fill,drawbox=x=100:y=190:w=240:h=300:color=0x102a36@0.72:t=fill,drawbox=x=390:y=190:w=240:h=300:color=0x102a36@0.72:t=fill,drawbox=x=680:y=190:w=240:h=300:color=0x102a36@0.72:t=fill,drawbox=x=970:y=190:w=240:h=300:color=0x102a36@0.72:t=fill,drawbox=x='mod(t*56\,1280)':y=130:w=5:h=460:color=0xd4933b@0.5:t=fill"
    },
    [ordered]@{
        Name = "leave-to-0001"
        Duration = 60
        Serial = 1734
        NoiseSeed = 101
        Tone = 66
        Visual = "drawbox=x=0:y=90:w=1280:h=540:color=0x07131d@0.86:t=fill,drawbox=x=180:y=160:w=920:h=400:color=0x0c202b@0.94:t=fill,drawbox=x=370:y=220:w=540:h=280:color=0x173c42@0.9:t=fill,drawbox=x=550:y=280:w=180:h=160:color=0xc8d9c4@0.28:t=fill,drawbox=x='mod(t*24\,900)+180':y=552:w=90:h=3:color=0xd4933b@0.78:t=fill"
    }
)

$ffmpegVersion = (& $FfmpegPath -version | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ffmpegVersion)) {
    throw "FFmpeg is required to generate the zero-echo formal media."
}
$ffmpegExecutable = (Get-Command $FfmpegPath -ErrorAction Stop).Source
$ffprobeExecutable = (Get-Command $FfprobePath -ErrorAction Stop).Source
$ffmpegSha256 = (Get-FileHash -LiteralPath $ffmpegExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
$ffprobeSha256 = (Get-FileHash -LiteralPath $ffprobeExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
& $FfprobePath -version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "FFprobe is required to validate the zero-echo formal media."
}

$manifestClips = @()
foreach ($clip in $clips) {
    $durationText = ([double]$clip.Duration).ToString([Globalization.CultureInfo]::InvariantCulture)
    $fadeOutText = ([double]($clip.Duration - 2)).ToString([Globalization.CultureInfo]::InvariantCulture)
    $frameCount = [int]$clip.Duration * 24
    $outputPath = Join-Path $outputDirectory ("{0}.ogv" -f $clip.Name)
    $videoSource = "color=c=0x06131f:s=1280x720:r=24:d=$durationText"
    $noiseSource = "anoisesrc=color=brown:amplitude=0.08:sample_rate=48000:duration=${durationText}:seed=$($clip.NoiseSeed)"
    $toneSource = "sine=frequency=$($clip.Tone):sample_rate=48000:duration=${durationText}"
    $videoFilter = "drawgrid=width=128:height=90:color=0x3ba6aa@0.055:thickness=1,$($clip.Visual),fade=t=in:st=0:d=1,fade=t=out:st=${fadeOutText}:d=2,format=yuv420p,trim=duration=$durationText,setpts=PTS-STARTPTS"
    $filterComplex = "[0:v]$videoFilter[v];[1:a]highpass=f=35,lowpass=f=1400,volume=0.14[a1];[2:a]volume=0.025[a2];[a1][a2]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.5,afade=t=in:st=0:d=1,afade=t=out:st=${fadeOutText}:d=2,atrim=duration=$durationText,asetpts=PTS-STARTPTS[a]"

    $ffmpegArgs = @(
        "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", $videoSource,
        "-f", "lavfi", "-i", $noiseSource,
        "-f", "lavfi", "-i", $toneSource,
        "-filter_complex", $filterComplex,
        "-map", "[v]", "-map", "[a]",
        "-map_metadata", "-1", "-map_chapters", "-1",
        "-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact",
        "-frames:v", "$frameCount", "-t", $durationText,
        "-c:v", "libtheora", "-q:v", "4", "-pix_fmt", "yuv420p", "-g", "48",
        "-c:a", "libvorbis", "-q:a", "1", "-ar", "48000", "-ac", "1",
        "-serial_offset", "$($clip.Serial)", "-page_duration", "1000000",
        $outputPath
    )
    Write-Output "Generating $($clip.Name) ($durationText seconds)..."
    & $FfmpegPath @ffmpegArgs
    if ($LASTEXITCODE -ne 0) {
        throw "FFmpeg failed to generate $($clip.Name).ogv."
    }

    $probeJson = & $FfprobePath -v error -show_entries "format=format_name,duration,size,bit_rate:stream=index,codec_type,codec_name,width,height,pix_fmt,r_frame_rate,sample_rate,channels" -of json $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "FFprobe failed for $($clip.Name).ogv."
    }
    $probe = $probeJson | ConvertFrom-Json
    $videoStreams = @($probe.streams | Where-Object { $_.codec_type -eq "video" })
    $audioStreams = @($probe.streams | Where-Object { $_.codec_type -eq "audio" })
    $actualDuration = [double]::Parse($probe.format.duration, [Globalization.CultureInfo]::InvariantCulture)
    $actualBytes = [int64]$probe.format.size
    if (
        $probe.format.format_name -notmatch "ogg" -or
        $videoStreams.Count -ne 1 -or $videoStreams[0].codec_name -ne "theora" -or
        $videoStreams[0].width -ne 1280 -or $videoStreams[0].height -ne 720 -or
        $videoStreams[0].pix_fmt -ne "yuv420p" -or $videoStreams[0].r_frame_rate -ne "24/1" -or
        $audioStreams.Count -ne 1 -or $audioStreams[0].codec_name -ne "vorbis" -or
        $audioStreams[0].sample_rate -ne "48000" -or $audioStreams[0].channels -ne 1 -or
        [Math]::Abs($actualDuration - [double]$clip.Duration) -gt 0.1 -or
        $actualBytes -gt 4MB
    ) {
        throw "Generated media contract failed for $($clip.Name).ogv: $probeJson"
    }

    & $FfmpegPath -v error -xerror -i $outputPath -map 0:v:0 -map 0:a:0 -f null NUL
    if ($LASTEXITCODE -ne 0) {
        throw "Full decode validation failed for $($clip.Name).ogv."
    }
    $manifestClips += [ordered]@{
        file = "$($clip.Name).ogv"
        duration_seconds = [double]$clip.Duration
        width = 1280
        height = 720
        fps = "24/1"
        video_codec = "theora"
        audio_codec = "vorbis"
        sample_rate = 48000
        channels = 1
        bytes = $actualBytes
        sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifest = [ordered]@{
    format_version = "0.1"
    generator = "tools/media/generate_zero_echo.ps1"
    ffmpeg = $ffmpegVersion
    ffmpeg_sha256 = $ffmpegSha256
    ffprobe_sha256 = $ffprobeSha256
    source = "CineWeave-original procedural geometry and synthesized ambience"
    encoding = [ordered]@{
        video = "libtheora q=4, 1280x720, 24/1 fps, yuv420p, keyframe interval 48"
        audio = "libvorbis q=1, 48000 Hz, mono"
        metadata = "stripped; fixed serial offsets and noise seeds; bitexact flags enabled"
    }
    clips = $manifestClips
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

& (Join-Path $repoRoot "tools\content\sync_storypacks.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "StoryPack synchronization failed after media generation."
}

Write-Output "Generated and validated $($clips.Count) formal zero-echo clips."
Write-Output "Manifest: $manifestPath"
