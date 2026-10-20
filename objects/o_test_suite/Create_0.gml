/// @desc Runs the Simple-Curves test suite through Crispy.
///       This object is also used by the suite as a disposable animation target.

// The lifecycle tests create temporary instances of this object.
if (variable_global_exists("__sc_dummy_pending") && global.__sc_dummy_pending)
{
	global.__sc_dummy_pending = false;
	__sc_dummy = true;
}

if (variable_instance_exists(id, "__sc_dummy") && __sc_dummy) exit;

global.__sc_test_runner = __scurve_test_runner();
global.__sc_test_runner.Run();
