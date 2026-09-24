# Level resources

Every `.tres` here is a [`Level`](../../features/levels/level.gd) — one
playable level's background, medium and floater tuning, with no code of its
own. [`LevelSelect`](../../features/ui/level_select/level_select.gd) scans
this folder at runtime and builds its list from whatever it finds, so adding
a level is dropping a `.tres` here rather than editing a hardcoded list.

`display_name` and `blurb` exist only for that screen's cards; everything
else is read by [`PanoramaLevel`](../../features/levels/panorama/panorama_level.gd),
the scene every discovered level is played through.

`overcast_sky.tres` and `dim_interior.tres` are the same two presets
`Level.overcast_sky()` and `Level.dim_interior()` build in code (still used by
`features/ui/demo_menu/`'s dev-only entries and `test_level.gd`), saved as
data instead so the level select has something real to discover. Their
`panorama_texture` is a `GradientTexture2D` over a three-stop `Gradient`
rather than a shipped image — a `.tres` can describe that gradient directly,
so there is no binary asset and nothing for `Level._gradient_panorama` to
generate at load time.

The secret eye tank (`features/levels/secret_eyes/`) is not here: it is not
built from a `Level`/`PanoramaLevel` at all, and reaching it is meant to stay
a secret rather than something this folder's ordinary discovery would surface
on its own. See that folder's README for how it is reached instead.
