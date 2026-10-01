# EyeGaze for iOS

ARKit face tracking behind the `EyeGaze` engine singleton that
[`NativeEyeGazeBackend`](../../../core/look/gaze/backends/native_eye_gaze_backend.gd)
reads. The contract (methods, dictionary keys, sign conventions) is in the
[gaze README](../../../core/look/gaze/README.md). Nothing iOS-specific leaks
past it.

Needs a TrueDepth front camera (iPhone X and later, excluding SE models). On
anything else the plugin reports `UNAVAILABLE`, and the game plays as it
would without it.

## Layout

| Path | |
| --- | --- |
| `native/ios/eye_gaze/eye_gaze.{h,mm}` | The plugin: a Godot `Object` plus an `ARSessionDelegate`. |
| `native/ios/eye_gaze/build.sh` | Builds `eye_gaze.debug.a` and `eye_gaze.release.a`. |
| `ios/plugins/eye_gaze/eye_gaze.gdip` | Tells Godot's iOS exporter to link it, with ARKit and AVFoundation. |

The `.a` files are build products and are gitignored.
`scripts/build-ios.sh` runs `build.sh` before every export; it does nothing
when the libraries are up to date. The first build clones Godot 4.4-stable's
source into `~/Library/Caches/godot-project-1/` for its headers and runs a
short, interrupted SCons pass to generate the few headers Godot writes at
build time. That takes a few minutes once; after that a build takes seconds.

The export preset turns it on (`plugins/EyeGaze=true`) and sets
`privacy/camera_usage_description`, which iOS shows in the permission prompt.

## Why a `.gdip` plugin rather than a GDExtension

Both work on iOS in Godot 4.4. The difference is what they do on every
**other** platform:

- A `.gdextension` file is loaded by every build of the project. With only an
  iOS library in it, the macOS editor, `scripts/run.sh`, the GUT run and the
  Linux CI export all log `ERROR: No GDExtension library found for current OS
  and architecture` on every launch (tried; see the PR). Silencing that means
  shipping stub libraries for every desktop platform. Those stubs would also
  register the singleton, so desktop builds would change too.
- A `.gdip` plugin is read only by the iOS exporter. Desktop never sees it.
  Android's plugin v2 (an AAR the Android exporter links) works the same way,
  so both backends are export-time, both register an engine singleton, and
  the GDScript side is identical.

What `.gdip` costs: it compiles against engine headers, not a stable ABI, so
it must be rebuilt for each engine version. The project pins 4.4, and
`build.sh` pins `GODOT_TAG`. Bump both together.

## How gaze is measured

Per ARKit frame, on ARKit's own serial queue:

1. No tracked `ARFaceAnchor`: the state is `NO_FACE`.
2. Face pose in view space: `camera.viewMatrixForOrientation(interface
   orientation) × face.transform`. In view space +y is the top of the screen.
3. The code does not assume which way view-space z faces the player. The face
   is on one side of the camera, and that side is towards the player. "Right"
   is `up × towards_player`, flipped if the view matrix is left-handed. That
   makes "right" the player's right whatever convention ARKit uses for the
   front camera.
4. Gaze is the mean of `leftEyeTransform` and `rightEyeTransform`'s +z axes,
   rotated into view space. Head direction is the face's +z axis.
5. Yaw is `atan2(right, into)` and pitch is `atan2(up, horizontal)`, measured
   from perpendicular to the screen.
6. `blink` is the larger of `eyeBlinkLeft` and `eyeBlinkRight`.
7. ARKit gives no gaze confidence, so `confidence` falls from 1 at about 37°
   of head turn to 0 at 60°, where eye estimates degrade.
8. `timestamp` is `ARFrame.timestamp` (system uptime).

No camera image is kept, copied or sent anywhere. Only the numbers above leave
the delegate, and the plugin makes no network calls.

The camera permission is requested on the first `start()`. A refusal reports
`PERMISSION_DENIED` until it is turned back on in Settings. An ARKit
interruption, such as the app going to the background or another app taking
the camera, reports `FAILED` ("interrupted") and restarts on its own when the
interruption ends.

## Verifying on a phone

Face tracking does not run in the simulator. See the manual test script in
the iOS PR description. In short, run `scripts/build-ios.sh`, open **Eye
Gaze** from the menu, and check that:

- the state goes `STARTING` → `NO_FACE` with the phone face down, then
  `TRACKING` when a face is in view;
- looking at the right edge of the screen makes gaze yaw positive, and looking
  at the top makes gaze pitch positive;
- turning the head right makes head yaw positive;
- after Calibrate, holding a look at an edge turns the heading that way;
- in **Overcast Sky**, the same held look turns the panorama.

If the signs come out mirrored, the fix is the sign of `right` in
`measure:camera:into:`. The GDScript side does not change.
