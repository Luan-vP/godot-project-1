# addons/

## gut/

[GUT (Godot Unit Test)](https://github.com/bitwes/Gut) v9.4.0, vendored directly
into `addons/gut/`. Targets Godot 4.4. See `res://tests/` for an example test
and the root README for how to run the suite.

## GodotSteam — not vendored, manual setup required

GodotSteam was **not** added automatically. As of this scaffolding
(Godot 4.4.1, GodotSteam 4.13 was the release that targeted Godot 4.4), the
project's GitHub repository (`GodotSteam/GodotSteam`) has since been archived
and its releases now live primarily on Codeberg. Both hosts were unreachable
from this environment's network egress policy, so the exact prebuilt
GDExtension binary for Godot 4.4 could not be downloaded or verified here.

To add it yourself:

1. Go to the GodotSteam releases page and grab the build matching your
   Godot version (4.4.x):
   - GitHub (archived, read-only mirror): https://github.com/GodotSteam/GodotSteam/releases
   - Codeberg (current canonical host): https://codeberg.org/godotsteam/godotsteam/releases
2. Unzip the release and copy its `addons/godotsteam/` (or equivalent)
   folder into this project's `addons/` directory.
3. Also drop a copy of `steam_api.dll` / `libsteam_api.so` (from the
   Steamworks SDK, per GodotSteam's install docs) next to your exported
   binary, and add `steam_appid.txt` with your Steam App ID for local
   testing.
4. Enable the plugin in Project Settings → Plugins, and re-check
   `project.godot`'s `[editor_plugins]` `enabled` array picks it up.
5. GodotSteam requires a Steamworks SDK you must obtain yourself from
   Valve's partner site (its license does not permit redistribution) —
   this step cannot be automated.

Steam deployment itself (steamcmd + VDF scripts, Steam Guard login) is left
as a manual/commented stub in `.github/workflows/build.yml` — see the TODO
there.
