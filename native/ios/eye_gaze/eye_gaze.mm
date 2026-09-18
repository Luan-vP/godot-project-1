// EyeGaze for iOS. See eye_gaze.h and core/look/gaze/README.md.
//
// ARKit face tracking runs on its own serial queue; each frame is reduced to
// a handful of numbers under a lock, and get_sample() copies them out on the
// game's thread. No camera image is kept, copied, or sent anywhere: ARKit
// hands over an anchor, and only the angles derived from it leave this file.

#include "eye_gaze.h"

#include "core/config/engine.h"

#import <ARKit/ARKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <os/lock.h>
#include <simd/simd.h>

// Must match EyeGazeSample.State in core/look/gaze/eye_gaze_sample.gd.
enum EyeGazeState : int {
	STATE_UNAVAILABLE = 0,
	STATE_STOPPED = 1,
	STATE_STARTING = 2,
	STATE_PERMISSION_DENIED = 3,
	STATE_NO_FACE = 4,
	STATE_TRACKING = 5,
	STATE_FAILED = 6,
};

struct EyeGazeReading {
	int state = STATE_STOPPED;
	float gaze_yaw = 0.0f;
	float gaze_pitch = 0.0f;
	float head_yaw = 0.0f;
	float head_pitch = 0.0f;
	float confidence = 0.0f;
	float blink = 0.0f;
	double timestamp = 0.0;
};

// Yaw and pitch of a direction, in the screen's frame: yaw positive towards
// the screen's right as the player sees it, pitch positive towards its top,
// zero straight into the screen.
static void screen_angles(simd_float3 direction, simd_float3 right, simd_float3 up, simd_float3 into, float *r_yaw, float *r_pitch) {
	float x = simd_dot(direction, right);
	float y = simd_dot(direction, up);
	float z = simd_dot(direction, into);
	*r_yaw = atan2(x, z);
	*r_pitch = atan2(y, sqrt(x * x + z * z));
}

static simd_float3 xyz(simd_float4 v) {
	return simd_make_float3(v.x, v.y, v.z);
}

@interface EyeGazeSession : NSObject <ARSessionDelegate>
- (void)start;
- (void)stop;
- (EyeGazeReading)reading:(NSString *__autoreleasing *)r_message;
@end

@implementation EyeGazeSession {
	ARSession *_session;
	dispatch_queue_t _queue;
	os_unfair_lock _lock;
	EyeGazeReading _reading;
	NSString *_message;
	BOOL _wanted;
	UIInterfaceOrientation _orientation;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_queue = dispatch_queue_create("eye_gaze.arkit", DISPATCH_QUEUE_SERIAL);
		_lock = OS_UNFAIR_LOCK_INIT;
		_message = @"";
		_orientation = UIInterfaceOrientationPortrait;
		if (!ARFaceTrackingConfiguration.isSupported) {
			_reading.state = STATE_UNAVAILABLE;
			_message = @"face tracking needs a TrueDepth camera";
		}
	}
	return self;
}

- (void)dealloc {
	[_session pause];
}

- (void)setState:(int)state message:(NSString *)message {
	os_unfair_lock_lock(&_lock);
	_reading.state = state;
	_reading.confidence = 0.0f;
	_message = [message copy];
	os_unfair_lock_unlock(&_lock);
}

- (EyeGazeReading)reading:(NSString *__autoreleasing *)r_message {
	os_unfair_lock_lock(&_lock);
	EyeGazeReading copy = _reading;
	*r_message = _message;
	os_unfair_lock_unlock(&_lock);
	return copy;
}

- (void)start {
	if (!ARFaceTrackingConfiguration.isSupported) {
		return;
	}
	_wanted = YES;
	[self captureOrientation];
	switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
		case AVAuthorizationStatusAuthorized:
			[self runSession];
			break;
		case AVAuthorizationStatusNotDetermined: {
			[self setState:STATE_STARTING message:@"waiting for camera permission"];
			[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
									 completionHandler:^(BOOL granted) {
										 dispatch_async(dispatch_get_main_queue(), ^{
											 if (!self->_wanted) {
												 return;
											 }
											 if (granted) {
												 [self runSession];
											 } else {
												 [self setState:STATE_PERMISSION_DENIED message:@"camera access declined"];
											 }
										 });
									 }];
			break;
		}
		default:
			[self setState:STATE_PERMISSION_DENIED message:@"camera access is off in Settings"];
			break;
	}
}

- (void)stop {
	if (!ARFaceTrackingConfiguration.isSupported) {
		return;
	}
	_wanted = NO;
	[_session pause];
	[self setState:STATE_STOPPED message:@""];
}

// Gaze is reported relative to the screen as the player sees it, so the
// interface orientation decides which way is up. Read once per start, on the
// main thread: the game is portrait-locked today.
- (void)captureOrientation {
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if ([scene isKindOfClass:UIWindowScene.class]) {
			_orientation = ((UIWindowScene *)scene).interfaceOrientation;
			return;
		}
	}
}

- (void)runSession {
	if (_session == nil) {
		_session = [ARSession new];
		_session.delegate = self;
		_session.delegateQueue = _queue;
	}
	ARFaceTrackingConfiguration *configuration = [ARFaceTrackingConfiguration new];
	configuration.lightEstimationEnabled = NO;
	configuration.maximumNumberOfTrackedFaces = 1;
	[self setState:STATE_STARTING message:@"camera starting"];
	[_session runWithConfiguration:configuration
						   options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
	ARFaceAnchor *face = nil;
	for (ARAnchor *anchor in frame.anchors) {
		if ([anchor isKindOfClass:ARFaceAnchor.class]) {
			face = (ARFaceAnchor *)anchor;
			break;
		}
	}

	EyeGazeReading reading;
	reading.timestamp = frame.timestamp;
	NSString *message = @"";
	if (face == nil || !face.isTracked) {
		reading.state = STATE_NO_FACE;
	} else {
		reading.state = STATE_TRACKING;
		[self measure:face camera:frame.camera into:&reading];
		NSNumber *left = face.blendShapes[ARBlendShapeLocationEyeBlinkLeft];
		NSNumber *right = face.blendShapes[ARBlendShapeLocationEyeBlinkRight];
		// The more closed eye: gaze from either closing eye is junk.
		reading.blink = MAX(left.floatValue, right.floatValue);
	}

	os_unfair_lock_lock(&_lock);
	// A stop() may have landed while this frame was in flight.
	if (_wanted) {
		_reading = reading;
		_message = message;
	}
	os_unfair_lock_unlock(&_lock);
}

- (void)measure:(ARFaceAnchor *)face camera:(ARCamera *)camera into:(EyeGazeReading *)r_reading {
	// World -> view for the current interface orientation: view-space +y is
	// the top of the screen. Which way view-space z faces the player is not
	// assumed — the face is simply on one side of the camera — and the
	// matrix's handedness is checked rather than trusted, so "right" is the
	// player's right either way.
	simd_float4x4 view = [camera viewMatrixForOrientation:_orientation];
	simd_float4x4 face_in_view = simd_mul(view, face.transform);
	simd_float3x3 rotation = simd_matrix(xyz(face_in_view.columns[0]), xyz(face_in_view.columns[1]), xyz(face_in_view.columns[2]));
	simd_float3x3 view_rotation = simd_matrix(xyz(view.columns[0]), xyz(view.columns[1]), xyz(view.columns[2]));

	simd_float3 face_position = xyz(face_in_view.columns[3]);
	simd_float3 towards_player = simd_make_float3(0.0f, 0.0f, face_position.z >= 0.0f ? 1.0f : -1.0f);
	simd_float3 into = -towards_player;
	simd_float3 up = simd_make_float3(0.0f, 1.0f, 0.0f);
	float handedness = simd_determinant(view_rotation) < 0.0f ? -1.0f : 1.0f;
	simd_float3 right = simd_cross(up, towards_player) * handedness;

	// Each eye's +z points out along its gaze, in face space. Averaged: ARKit
	// estimates the two together, and the mean steadies the jitter.
	simd_float3 eyes = xyz(face.leftEyeTransform.columns[2]) + xyz(face.rightEyeTransform.columns[2]);
	simd_float3 gaze = simd_normalize(simd_mul(rotation, simd_normalize(eyes)));
	// Face +z points out of the face.
	simd_float3 head = simd_normalize(xyz(face_in_view.columns[2]));

	screen_angles(gaze, right, up, into, &r_reading->gaze_yaw, &r_reading->gaze_pitch);
	screen_angles(head, right, up, into, &r_reading->head_yaw, &r_reading->head_pitch);

	// ARKit gives no gaze confidence. Eye estimates degrade as the head turns
	// away, so trust falls off from full at ~37 degrees to none at 60.
	float facing = simd_dot(head, into);
	r_reading->confidence = simd_clamp((facing - 0.5f) / 0.3f, 0.0f, 1.0f);
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
	BOOL denied = [error.domain isEqualToString:ARErrorDomain] && error.code == ARErrorCodeCameraUnauthorized;
	[self setState:(denied ? STATE_PERMISSION_DENIED : STATE_FAILED) message:error.localizedDescription];
}

- (void)sessionWasInterrupted:(ARSession *)session {
	[self setState:STATE_FAILED message:@"interrupted"];
}

- (void)sessionInterruptionEnded:(ARSession *)session {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self->_wanted) {
			[self runSession];
		}
	});
}

@end

void EyeGaze::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start"), &EyeGaze::start);
	ClassDB::bind_method(D_METHOD("stop"), &EyeGaze::stop);
	ClassDB::bind_method(D_METHOD("get_sample"), &EyeGaze::get_sample);
	ClassDB::bind_method(D_METHOD("get_api_version"), &EyeGaze::get_api_version);
}

void EyeGaze::start() {
	[session start];
}

void EyeGaze::stop() {
	[session stop];
}

Dictionary EyeGaze::get_sample() {
	NSString *message = nil;
	EyeGazeReading reading = [session reading:&message];
	Dictionary sample;
	sample["state"] = reading.state;
	sample["gaze_yaw"] = reading.gaze_yaw;
	sample["gaze_pitch"] = reading.gaze_pitch;
	sample["head_yaw"] = reading.head_yaw;
	sample["head_pitch"] = reading.head_pitch;
	sample["confidence"] = reading.confidence;
	sample["blink"] = reading.blink;
	sample["timestamp"] = reading.timestamp;
	sample["message"] = String::utf8(message != nil ? message.UTF8String : "");
	return sample;
}

int EyeGaze::get_api_version() const {
	return API_VERSION;
}

EyeGaze::EyeGaze() {
	session = [EyeGazeSession new];
}

EyeGaze::~EyeGaze() {
	[session stop];
	session = nil;
}

static EyeGaze *eye_gaze_singleton = nullptr;

void eye_gaze_plugin_init() {
	eye_gaze_singleton = memnew(EyeGaze);
	Engine::get_singleton()->add_singleton(Engine::Singleton("EyeGaze", eye_gaze_singleton));
}

void eye_gaze_plugin_deinit() {
	if (eye_gaze_singleton != nullptr) {
		memdelete(eye_gaze_singleton);
		eye_gaze_singleton = nullptr;
	}
}
