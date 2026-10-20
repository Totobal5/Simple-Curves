#export SC_VERSION, SC_LOG_ALERTS, SC_LOG_ALERTS_PROPERTY, SC_LOG_ALERTS_PLAY, SC_LOG_ERRORS, SC_FATAL_ERRORS, SC_MIN_DELTA_FPS, SC_MIN_PHASE_DURATION, SC_PATROL_MODE_GO, SC_PATROL_MODE_WAIT, SC_PATROL_MODE_BACK, SC_LAUNCH_ON_FINISH, SC_TYPE_TO, SC_TYPE_PATROL
#export SCURVE

/// @ignore [MAJOR.MINOR.PATCH]
#macro SC_VERSION	"1.0.0"

/// @ignore Show debug alerts for SCurve events (true/false).
#macro SC_LOG_ALERTS			true

/// @ignore Show debug alerts for property configuration (true/false).
#macro SC_LOG_ALERTS_PROPERTY	true

/// @ignore Show debug alerts for Play() calls (true/false).
#macro SC_LOG_ALERTS_PLAY		true

/// @ignore Show errors in the console
#macro SC_LOG_ERRORS			true

/// @ignore Crash the game on errors (true/false). If false, errors will be logged but the game will continue.
#macro SC_FATAL_ERRORS			true

/// @ignore Minimum delta time for FPS protection. If the game drops below this FPS, SCurve will use a safe delta to avoid abrupt jumps.
#macro SC_MIN_DELTA_FPS			15

/// @ignore Minimum phase duration to avoid division by zero or extremely fast animations.
#macro SC_MIN_PHASE_DURATION	0.000001

/// @desc Patrol modes for SCurve animations.
#macro SC_PATROL_MODE_GO		"go"

/// @ignore 
#macro SC_PATROL_MODE_WAIT		"wait"

/// @ignore
#macro SC_PATROL_MODE_BACK		"back"

/// @ignore 
#macro SC_LAUNCH_ON_FINISH		0

/// @desc Animation type for a simple transition to a target value.
#macro SC_TYPE_TO				"to"

/// @desc Animation type for a simple transition to a target value.
#macro SC_TYPE_PATROL			"patrol"

/// @desc Ease curve types for SCurve animations.
enum SCURVE
{
	LINEAR,
	EASE,
	CUBIC,
	QUART,
	EXPO,
	CIRC,
	BACK,
	ELASTIC,
	BOUNCE,
	FAST_SLOW,
	MID_SLOW
}

__scurve_alert($"v{SC_VERSION} loaded successfully.");
__scurve_alert($"Made by Toto (C.A).");