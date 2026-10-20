/// @ignore
/// @desc Prints trace messages when `SC_LOG_ALERTS` is active.
/// @param {String} _msg The message to display.
function __scurve_alert(_msg)
{
	if (SC_LOG_ALERTS)
	{
		var _origin = ytrace_origin;
		_origin = string_replace_all(_origin, "cyou_tobalsea_scurves_1_0_0___", "tobalsea_scurves_");
		show_debug_message($"Simple-Curves Alert:: {_origin}: {_msg}");
	}
}

/// @ignore
/// @desc Prints error messages when `SC_LOG_ERRORS` is active. If `SC_FATAL_ERRORS` is true, the game will crash on errors. Otherwise, errors will be logged but the game will continue.
/// @param {String} _msg The error message to display.
function __scurve_error(_msg)
{
	if (SC_LOG_ERRORS || SC_FATAL_ERRORS)
	{
		var _origin = ytrace_origin;
		_origin = string_replace_all(_origin, "cyou_tobalsea_scurves_1_0_0___", "tobalsea_scurves_");

		show_debug_message($"Simple-Curves Error:: {_origin}: {_msg}");
		// If strict mode is enabled crash the game with an error message to avoid silent failures.
		if (SC_FATAL_ERRORS) { show_error($"Simple-Curves Fatal Error:: {_origin}: {_msg}", true); }
	}
}

/// @desc Checks if a given struct is an instance of SCurve.
/// @param {Struct} _struct The struct to check.
/// @return {Bool} True if the struct is an SCurve instance, false otherwise.
function is_scurve(_struct)
{
	return is_instanceof(_struct, SCurve);
}
