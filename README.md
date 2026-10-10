# LoZ Client

Download the launcher from the [latest release](https://github.com/Apothim/LozClient/releases/latest),
put `LoZLauncher.exe` in its own folder (not Program Files), and run it. It downloads the game into a
`game` folder beside it, keeps it up to date, and starts it when you press **Play**.

The game itself is not open source; this repository holds the launcher and the published builds.

## Publishing a release (maintainers)

1. Export the game client into an empty folder (for example `build/0.2.0/`).
2. Write its manifest:
   ```
   godot --headless --path launcher --script res://tools/make_manifest.gd -- <build folder> 0.2.0 LoZ.exe
   ```
3. Create a GitHub release tagged `v0.2.0` and upload every file in the build folder, including
   `manifest.json`. A file in a subfolder is uploaded with `/` replaced by `.` (the manifest's `asset`).
4. Mark it as the latest release. Launchers pick it up on their next start.

Launchers always read `releases/latest/download/manifest.json`, and only install files whose SHA-256
matches the manifest. Manifest paths are checked so a release can never write outside the `game` folder.

## Launcher development

- Godot 4.7.2. Open `launcher/` as its own project.
- Tests: `godot --headless --path launcher --script res://tests/updater_tests.gd` (exit 0 = pass).
- Build: `godot --headless --path launcher --export-release "Windows Launcher"` writes `build/LoZLauncher.exe`
  (needs the 4.7.2 export templates). Attach it to releases so new players can get it.
