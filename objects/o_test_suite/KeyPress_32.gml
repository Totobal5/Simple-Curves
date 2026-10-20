/// @desc Press Space to run the full suite again.

if (variable_instance_exists(id, "__sc_dummy") && __sc_dummy) exit;

global.__sc_test_runner = __scurve_test_runner();
global.__sc_test_runner.Run();
