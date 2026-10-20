/// @ignore
/// @desc Prints trace messages when `SC_LOG_ALERTS` is active.
/// @param {String} _msg The message to display.
function __scurve_alert(_msg)
{
	if (SC_LOG_ALERTS)
	{
		show_debug_message($"Simple-Curves Alert:: {__scurve_origin()}: {_msg}");
	}
}

/// @ignore
/// @desc Prints error messages when `SC_LOG_ERRORS` is active. If `SC_FATAL_ERRORS` is true, the game will crash on errors. Otherwise, errors will be logged but the game will continue.
///       Both flags can be overridden at runtime through `SCMaster.SetLogErrors()` and `SCMaster.SetFatalErrors()`.
/// @param {String} _msg The error message to display.
function __scurve_error(_msg)
{
	var _log = SCMaster.GetLogErrors();
	var _fatal = SCMaster.GetFatalErrors();
	if (!_log && !_fatal) return;

	var _origin = __scurve_origin();

	show_debug_message($"Simple-Curves Error:: {_origin}: {_msg}");
	// Halt the game on errors unless fatal errors were disabled at runtime.
	if (_fatal) show_error($"Simple-Curves Fatal Error:: {_origin}: {_msg}", true);
}

/// @desc Checks if a given struct is an instance of SCurve.
/// @param {Struct} _struct The struct to check.
/// @return {Bool} True if the struct is an SCurve instance, false otherwise.
function is_scurve(_struct)
{
	return is_instanceof(_struct, SCurve);
}

/// @ignore
/// @desc Strips the prefab prefix from a trace origin.
///       A prefab origin looks like "cyou_tobalsea_scurves_1_1_0_Simple_Curves_Functions:43";
///       the result keeps only "Simple_Curves_Functions:43". Origins from a plain project are returned untouched.
/// @param {String} _origin The raw trace origin.
/// @return {String} The cleaned origin.
function __scurve_strip_origin(_origin)
{
	var _prefix = "cyou_tobalsea_scurves_";

	// Not running from the prefab: nothing to strip.
	if (string_pos(_prefix, _origin) != 1) return _origin;

	var _rest = string_delete(_origin, 1, string_length(_prefix) );

	// Drop the version segment ("1_1_0_") the prefab injects before the script name.
	var _skip = 0;
	repeat(string_length(_rest) )
	{
		var _code = ord(string_char_at(_rest, _skip + 1) );

		// Digits and underscores belong to the version; anything else starts the script name.
		if ( (_code < 48 || _code > 57) && _code != 95) break;

		_skip++;
	}

	return string_delete(_rest, 1, _skip);
}

/// @ignore
/// @desc Returns the caller origin with the package prefix stripped, keeping log lines readable across versions.
/// @return {String} The cleaned caller origin.
function __scurve_origin()
{
	return __scurve_strip_origin(ytrace_origin);
}
