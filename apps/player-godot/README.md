# CineWeave Godot Player

This project is the V0.1 Windows Player baseline. It uses GDScript, the Compatibility renderer, a 1280×720 internal canvas and a responsive window. The current main scene is the approved cold, cinematic title shell; StoryPack playback arrives in the next vertical slice.

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

The runner accepts a GUI executable path when a sibling `_console.exe` exists and switches to the console launcher automatically. Success prints `PASS: CineWeave Godot startup baseline` and returns exit code zero. Missing project settings, main scene, project theme, title copy or primary action returns a non-zero code.

## Visual baseline

The title screen defines the first Player Theme Token set:

- deep navy and black surfaces;
- desaturated cyan interaction and divider colors;
- amber focus and warning accents;
- themed buttons, panels and focus state;
- restrained copy and generous negative space that keep the image area dominant.

Product screens inherit this theme instead of publishing Godot's default control appearance. The title button is intentionally only the visual entry point in this baseline; StoryRuntime wiring is owned by the next Ticket.
