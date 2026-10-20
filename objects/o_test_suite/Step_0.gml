/// @desc Pumps the asynchronous Crispy cases.

if (variable_instance_exists(id, "__sc_dummy") && __sc_dummy) exit;
if (!variable_global_exists("__sc_test_runner") || is_undefined(global.__sc_test_runner) ) exit;

if (global.__sc_test_runner.IsRunning() ) global.__sc_test_runner.Update();
