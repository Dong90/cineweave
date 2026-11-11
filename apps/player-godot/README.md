# CineWeave Godot Player

This project is the V0.1 Windows Player. It uses GDScript, the Compatibility renderer, a 1280×720 internal canvas and a responsive window. The approved cold, cinematic title shell now opens the bundled 《零点回声》 StoryPack, plays its Ogg Theora clip, renders Simplified Chinese subtitle cues from media time and enters the authored ending through StoryRuntime.

## Run with official Godot 4.7.2

Keep the official binary outside the repository, then run from the CineWeave root:

```powershell
& <godot-4.7.2-executable> --path .\apps\player-godot
```

The project must remain compatible with this unmodified official release even when a locally built Fork is available.

## Run with the pinned Fork

Initialize and build the engine using [`engine/README.md`](../../engine/README.md), then pass the generated editor executable the same project path.

## Headless smoke check

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_headless.ps1 -GodotPath <godot-console-executable>
```

The runner accepts a GUI executable path when a sibling `_console.exe` exists and switches to the console launcher automatically. Success prints `PASS: CineWeave Godot startup baseline` and returns exit code zero. The test crosses the public StoryRuntime seam, rejects invalid StoryPacks, loads the real media asset, observes a timed subtitle and converts playback completion to a PlayerAction before checking the ending. Contract failures return a non-zero code.

## StoryPack content

The authoritative sample lives under `content/samples/zero-echo`. Godot cannot import resources outside its project root, so the checked-in `content/zero-echo` directory inside this Player is a generated copy and must not be edited manually.

Regenerate the original procedural media and synchronize the Player copy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\media\generate_zero_echo.ps1
```

Synchronize an existing authoritative StoryPack without rebuilding media, or verify that the copy is current:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\content\sync_storypacks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\content\sync_storypacks.ps1 -Check
```

The media is project-original and procedurally generated; its source and license record is stored beside the authoritative StoryPack in `ASSET_SOURCE.md`.

## Visual baseline

The title screen defines the first Player Theme Token set:

- deep navy and black surfaces;
- desaturated cyan interaction and divider colors;
- amber focus and warning accents;
- themed buttons, panels and focus state;
- restrained copy and generous negative space that keep the image area dominant.

The playback stage, subtitle surface, ending and error overlay inherit the same Theme Token. Player UI callbacks only translate device events into PlayerAction and render StoryEffect; StoryNode progression remains inside StoryRuntime. Product screens inherit this theme instead of publishing Godot's default control appearance.
