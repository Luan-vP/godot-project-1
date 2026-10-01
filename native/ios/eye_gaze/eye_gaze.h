// EyeGaze for iOS: ARKit face tracking behind the engine singleton every
// platform's gaze plugin registers. The Godot-facing contract is documented in
// core/look/gaze/README.md; this file must not grow anything iOS-shaped into
// it, since NativeEyeGazeBackend reads Android through the same four methods.

#pragma once

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/dictionary.h"

#ifdef __OBJC__
@class EyeGazeSession;
#else
typedef void EyeGazeSession;
#endif

class EyeGaze : public Object {
	GDCLASS(EyeGaze, Object);

	EyeGazeSession *session = nullptr;

protected:
	static void _bind_methods();

public:
	static constexpr int API_VERSION = 1;

	void start();
	void stop();
	Dictionary get_sample();
	int get_api_version() const;

	EyeGaze();
	~EyeGaze();
};

// Called by the Godot iOS export's generated plugin glue (C++ linkage).
void eye_gaze_plugin_init();
void eye_gaze_plugin_deinit();
