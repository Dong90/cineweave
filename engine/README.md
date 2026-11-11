# Godot engine source

CineWeave keeps Godot as an independently versioned SDK source dependency. The product repository stores only a Git Submodule pointer; it does not copy Godot source or commit engine binaries.

## V0.1 pin

- Fork: `git@github.com:Dong90/godot.git`
- Required commit: `ed1daf0bf001b61586d9930840f2f1394092c079`
- Upstream identity: `4.7.2-stable`
- Official compatibility baseline: Godot 4.7.2 without CineWeave modifications

The Fork currently does not expose an independent `4.7.2-stable` tag, so the immutable commit is the source of truth. Never replace it with the Fork's moving `master` branch.

## Initialize

From the CineWeave repository root:

```powershell
git submodule update --init engine/godot
git -C engine/godot rev-parse HEAD
```

The second command must print the required commit above. A fresh clone may fetch that commit directly even though the Fork has no matching tag.

## Build the pinned Fork on Windows

Install Python 3 and Visual Studio 2022 Build Tools with the Desktop development with C++ workload. Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\engine\build.ps1 -Bootstrap
```

`-Bootstrap` creates an ignored Python virtual environment and installs the pinned SCons version. Later builds can omit it. Use `-Jobs <n>` to limit parallel work or `-DevBuild` for an engine development build. The V0.1 script explicitly disables AccessKit, ANGLE and Direct3D 12 because this Player baseline uses the native Compatibility renderer and does not yet ship those optional SDK dependencies. Build products stay inside Godot's ignored `bin` directory and must not be added to CineWeave.

Run the Player with the produced editor executable:

```powershell
& .\engine\godot\bin\godot.windows.editor.x86_64.exe --path .\apps\player-godot
```

The exact artifact name can include build suffixes; `engine/build.ps1` prints every matching executable when it succeeds.

## Verify official compatibility

Keep an official Godot 4.7.2 binary outside this repository and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_headless.ps1 -GodotPath <official-console-executable>
```

After building the Fork, run the same command with its console executable. Both runs must print `PASS: CineWeave Godot startup baseline`.

## Update the engine version

Only update the pin on a dedicated `feature/CW-<issue>-<slug>` branch with a compatibility decision and tests:

```powershell
git -C engine/godot fetch origin <approved-commit>
git -C engine/godot checkout --detach <approved-commit>
git add engine/godot
```

Record the new commit and compatibility range in an ADR. Existing release tags keep their original Submodule commit; never move a published pin in place.

Godot's MIT license remains at `engine/godot/LICENSE.txt`; see the repository's `THIRD_PARTY_NOTICES.md` for attribution.
