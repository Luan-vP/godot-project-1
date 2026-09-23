# addons/

## gut/

[GUT (Godot Unit Test)](https://github.com/bitwes/Gut) v9.4.0, vendored directly
into `addons/gut/`. Targets Godot 4.4. See `res://tests/` for an example test
and the root README for how to run the suite.

## godotsteam/

[GodotSteam GDExtension](https://codeberg.org/godotsteam/godotsteam) 4.20.1
(Steamworks SDK 1.64), vendored into `addons/godotsteam/` from the release's
`godotsteam-4.20.1-gdextension-plugin-4.4.zip`. It is what gives the game
Steam Input, and with it controller motion on every pad Steam supports — see
[`core/motion/README.md`](../core/motion/README.md).

**Pinned to 4.20.1, deliberately.** 4.22 and 4.22.1 segfault Godot 4.4.1
during export — `--export-release` dies with signal 11 inside
`libgodotsteam`, before writing anything. It is not this project: a project
containing nothing but `project.godot`, an export preset and the addon
crashes the same way, on a display and headless alike, with the release's
own untouched files. 4.20.1 and 4.18.1 both export cleanly on the same
machine. Upgrading means re-testing an export on Godot 4.4.1 first, or
moving the engine on.

**Trimmed to the platforms this project ships.** The release also carries
`androidarm64`, `linux32`, `linuxarm64` and `win32` builds; dropping them
takes the addon from 97 MB to 30 MB, and their entries are removed from
`godotsteam.gdextension` to match. Adding a platform back means taking both
its directory and its `[libraries]`/`[dependencies]` lines from the release
zip, unedited.

**No Steamworks SDK download is needed.** The GDExtension release bundles the
`libsteam_api` redistributables it links against, which is the part the older
module builds made you fetch from Valve's partner site by hand.

**The editor plugin is not enabled** in `project.godot`. The extension itself
loads from its `.gdextension` regardless; the plugin only adds a Steamworks
panel to the editor, and leaving it off keeps CI from needing it.

**An app ID is needed at runtime.** `SteamInputMotionSource` initialises with
480 (Valve's public test app) until the game has its own;
`scripts/deck-build.sh` writes a `steam_appid.txt` beside the exported binary
so a build launched outside Steam can still reach a running client. Leave that
file out of a shipped build.

Steam deployment itself (steamcmd + VDF scripts, Steam Guard login) is left
as a manual/commented stub in `.github/workflows/build.yml` — see the TODO
there.
