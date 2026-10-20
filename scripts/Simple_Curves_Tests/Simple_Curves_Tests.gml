/// @desc Simple-Curves test suite, powered by Crispy.
///       Every `test_<suite>_*` function is discovered and turned into a CrispyCase.
///       Functions whose name contains `_async` become CrispyCaseAsync and are driven by the runner's Step updates.

#region HELPERS

/// @desc Builds the Crispy runner with every Simple-Curves suite registered.
/// @return {Struct.CrispyRunner} The configured runner.
function __scurve_test_runner()
{
	var _runner = new CrispyRunner("simple_curves");

	__sc_test_suite(_runner, "config", "test_config_");
	__sc_test_suite(_runner, "guards", "test_guard_");
	__sc_test_suite(_runner, "relative", "test_relative_");
	__sc_test_suite(_runner, "tags", "test_tag_");
	__sc_test_suite(_runner, "manager", "test_manager_");
	__sc_test_suite(_runner, "lifecycle", "test_life_");

	// The animation suite runs asynchronous cases concurrently, so it cannot reset between cases.
	__sc_test_suite(_runner, "animation", "test_anim_", false);

	return _runner;
}

/// @ignore
/// @desc Creates a suite with the shared Simple-Curves set-up and tear-down, then discovers its cases.
/// @param {Struct.CrispyRunner} _runner Runner that will execute the suite.
/// @param {String} _name Suite name.
/// @param {String} _pattern Function prefix used to discover the cases.
/// @param {Bool} [_reset_per_case=true] Destroy every tween after each case.
function __sc_test_suite(_runner, _name, _pattern, _reset_per_case = true)
{
	var _suite = new CrispySuite(_name)
		.SetUp(function()
		{
			// Contract violations are expected in the guard suite, so they must not halt the game.
			SCMaster.SetFatalErrors(false);
			SCMaster.SetLogErrors(false);
			SCMaster.SetGlobalTimeScale(1);
			SCMaster.DestroyAll();
		})
		.TearDown(function()
		{
			SCMaster.DestroyAll();
			SCMaster.SetGlobalTimeScale(1);
			SCMaster.SetLogErrors(SC_LOG_ERRORS);
			SCMaster.SetFatalErrors(SC_FATAL_ERRORS);
		});

	if (_reset_per_case)
	{
		_suite.OnRunEnd(function()
		{
			SCMaster.DestroyAll();
			SCMaster.SetGlobalTimeScale(1);
		});
	}

	_runner.AddTestSuite(_suite);
	_runner.Discover(_suite, _pattern);
}

/// @ignore
/// @desc Creates a tween aimed at a disposable struct, with auto-destroy disabled.
/// @param {Struct} _target Target struct.
/// @return {Struct.SCurve} The configured tween.
function __sc_test_tween(_target)
{
	return new SCurve(SCURVE.LINEAR, false).Target(_target);
}

/// @ignore
/// @desc Resolves an end value expression through a real SCurve and returns the cached result.
/// @param {Real} _start_value Initial value of the animated property.
/// @param {Any} _expression End value as configured by the user.
/// @return {Real} The resolved end value.
function __sc_test_resolved_finish(_start_value, _expression)
{
	var _target = { x: _start_value };
	var _tween = __sc_test_tween(_target).To(0.1, "x", _expression);
	_tween.Refresh();

	var _finish = _tween.__properties[0].__finish;
	_tween.Destroy();

	return _finish;
}

/// @ignore
/// @desc Creates a disposable instance of the test object to be used as an animation target.
/// @return {Id.Instance} The dummy instance.
function __sc_test_dummy_instance()
{
	global.__sc_dummy_pending = true;
	var _dummy = instance_create_depth(0, 0, 0, o_test_suite);
	global.__sc_dummy_pending = false;

	return _dummy;
}

#endregion

#region CONFIG

/// @desc A new tween starts idle: valid but not playing, not finished and without animation type.
function test_config_defaults()
{
	var _tween = new SCurve(SCURVE.EASE);

	AssertTrue(_tween.IsValid(), "A new tween must be usable");
	AssertFalse(_tween.IsPlaying(), "A new tween must not be playing");
	AssertFalse(_tween.IsPaused(), "A new tween must not be paused");
	AssertFalse(_tween.IsFinished(), "A new tween must not report itself as finished");
	AssertFalse(_tween.IsDelaying(), "A new tween must not be delaying");
	AssertFalse(_tween.IsReversed(), "A new tween must not start reversed");
	AssertEqual(_tween.GetType(), SC_TYPE.NONE, "A new tween must not have an animation type");
	AssertIsUndefined(_tween.GetPatrolState(), "Only Patrol tweens expose a patrol state");
	AssertEqual(_tween.GetRepeatCount(), 0, "No cycles should have completed yet");
	AssertNear(_tween.GetPhaseProgress(), 0, 0.0001);
}

/// @desc To() configures a single-direction animation and keeps every property pair.
function test_config_to_sets_type_and_properties()
{
	var _tween = __sc_test_tween({ x: 0, y: 0 }).To(1, "x", 10, "y", 20);

	AssertEqual(_tween.GetType(), SC_TYPE.TO);
	AssertEqual(array_length(_tween.__properties), 2, "Both property pairs must be registered");
	AssertIsUndefined(_tween.GetPatrolState(), "To() tweens have no patrol state");
}

/// @desc Patrol() configures the patrol type and starts in the GO phase.
function test_config_patrol_sets_type_and_state()
{
	var _tween = __sc_test_tween({ x: 0 }).Patrol(1, 1, 0.2, "x", 10);

	AssertEqual(_tween.GetType(), SC_TYPE.PATROL);
	AssertEqual(_tween.GetPatrolState(), SC_PATROL_MODE.GO, "Patrol must start moving forward");
}

/// @desc Every fluent setter returns the same instance so calls can be chained.
function test_config_setters_are_chainable()
{
	var _tween = __sc_test_tween({ x: 0 });
	var _id = _tween.__id;

	AssertEqual(_tween.Delay(0.1).__id, _id, "Delay() must return the same tween");
	AssertEqual(_tween.TimeScale(2).__id, _id, "TimeScale() must return the same tween");
	AssertEqual(_tween.Repeat(3).__id, _id, "Repeat() must return the same tween");
	AssertEqual(_tween.DestroyOnFinish(false).__id, _id, "DestroyOnFinish() must return the same tween");
	AssertEqual(_tween.Tag("chain").__id, _id, "Tag() must return the same tween");
	AssertEqual(_tween.To(1, "x", 5).__id, _id, "To() must return the same tween");
}

/// @desc is_scurve() recognizes tweens and rejects everything else.
function test_config_is_scurve()
{
	AssertTrue(is_scurve(__sc_test_tween({ x: 0 }) ) );
	AssertFalse(is_scurve({ x: 0 }), "A plain struct is not a tween");
	AssertFalse(is_scurve(undefined) );
}

/// @desc Every easing channel must map the ends of the timeline onto exactly 0 and 1,
///       otherwise a finished tween never lands on its end value.
function test_config_curve_channels_are_normalized()
{
	var _index = 0;
	var _channel = animcurve_get_channel(Simple_Curves_Animation, _index);

	while (!is_undefined(_channel) )
	{
		AssertNear(animcurve_channel_evaluate(_channel, 0), 0, 0.000001, $"Channel {_index} must start at 0");
		AssertNear(animcurve_channel_evaluate(_channel, 1), 1, 0.000001, $"Channel {_index} must end at 1");

		_index++;
		_channel = animcurve_get_channel(Simple_Curves_Animation, _index);
	}

	AssertTrue(_index > 0, "The animation curve must expose at least one channel");
}

/// @desc The SCURVE enum is coupled to the channel order by index, so both must have the same size.
function test_config_curve_channels_match_enum()
{
	var _count = 0;
	while (!is_undefined(animcurve_get_channel(Simple_Curves_Animation, _count) ) ) _count++;

	AssertEqual(_count, SCURVE.MID_SLOW + 1, "The animation curve must declare one channel per SCURVE value, in order");
}

/// @desc Two SCURVE values must never resolve to the same easing shape.
function test_config_curve_channels_are_distinct()
{
	var _count = 0;
	while (!is_undefined(animcurve_get_channel(Simple_Curves_Animation, _count) ) ) _count++;

	for (var i = 0; i < _count; i++)
	{
		var _first = animcurve_get_channel(Simple_Curves_Animation, i);

		for (var j = i + 1; j < _count; j++)
		{
			var _second = animcurve_get_channel(Simple_Curves_Animation, j);
			var _is_duplicate = true;

			for (var s = 1; s < 20; s++)
			{
				var _t = s / 20;

				if (abs(animcurve_channel_evaluate(_first, _t) - animcurve_channel_evaluate(_second, _t) ) > 0.0001)
				{
					_is_duplicate = false;
					break;
				}
			}

			AssertFalse(_is_duplicate, $"Channels {i} and {j} must not be identical easings");
		}
	}
}

#endregion

#region GUARDS

/// @desc Play() refuses to start a tween that has no animation configured.
function test_guard_play_without_animation()
{
	var _tween = __sc_test_tween({ x: 0 });
	_tween.Play();

	AssertFalse(_tween.IsPlaying(), "Play() must not start an unconfigured tween");
}

/// @desc A destroyed tween cannot be played again.
function test_guard_play_after_destroy()
{
	var _tween = __sc_test_tween({ x: 0 }).To(0.1, "x", 10);
	_tween.Destroy();
	_tween.Play();

	AssertFalse(_tween.IsValid() );
	AssertFalse(_tween.IsPlaying(), "A destroyed tween must stay dead");
}

/// @desc Configuring two animation types keeps the first one and ignores the second.
function test_guard_second_animation_is_ignored()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10).Patrol(1, 1, 0.1, "y", 20);

	AssertEqual(_tween.GetType(), SC_TYPE.TO, "The first configuration wins");
	AssertEqual(array_length(_tween.__properties), 1, "The ignored Patrol must not add properties");
}

/// @desc To() rejects negative durations and leaves the tween unconfigured.
function test_guard_to_invalid_duration()
{
	var _tween = __sc_test_tween({ x: 0 }).To(-1, "x", 10);

	AssertEqual(_tween.GetType(), SC_TYPE.NONE);
	AssertEqual(array_length(_tween.__properties), 0);
}

/// @desc To() rejects an incomplete (property, value) list.
function test_guard_to_odd_arguments()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x");

	AssertEqual(_tween.GetType(), SC_TYPE.NONE);
	AssertEqual(array_length(_tween.__properties), 0);
}

/// @desc Patrol() rejects negative durations and delays.
function test_guard_patrol_invalid_timings()
{
	AssertEqual(__sc_test_tween({ x: 0 }).Patrol(1, -1, 0.1, "x", 10).GetType(), SC_TYPE.NONE);
	AssertEqual(__sc_test_tween({ x: 0 }).Patrol(1, 1, -0.1, "x", 10).GetType(), SC_TYPE.NONE);
}

/// @desc Patrol() rejects an incomplete (property, value) list.
function test_guard_patrol_odd_arguments()
{
	var _tween = __sc_test_tween({ x: 0 }).Patrol(1, 1, 0.1, "x");

	AssertEqual(_tween.GetType(), SC_TYPE.NONE);
	AssertEqual(array_length(_tween.__properties), 0);
}

/// @desc Repeat() ignores zero and out-of-range cycle counts.
function test_guard_repeat_invalid_count()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);

	_tween.Repeat(0);
	AssertEqual(_tween.__repeats, 1, "Repeat(0) must not change the default single cycle");

	_tween.Repeat(-2);
	AssertEqual(_tween.__repeats, 1, "Counts below -1 are invalid");

	_tween.Repeat(-1);
	AssertEqual(_tween.__repeats, -1, "-1 must configure infinite cycles");
}

/// @desc Launch() ignores arguments that are not tweens.
function test_guard_launch_invalid_target()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);
	_tween.Launch({ not_a_tween: true });

	AssertEqual(array_length(_tween.__launch_data), 0);
}

/// @desc Tag() ignores empty and non-string tags.
function test_guard_tag_invalid_values()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);
	_tween.Tag("", 5, "valid");

	AssertEqual(array_length(_tween.__tags), 1);
	AssertTrue(_tween.HasTag("valid") );
	AssertFalse(_tween.HasTag("") );
}

/// @desc Properties missing on the target are marked invalid instead of crashing every frame.
function test_guard_missing_property()
{
	var _tween = __sc_test_tween({ y: 0 }).To(0.1, "x", 10);
	_tween.Refresh();

	AssertFalse(_tween.__properties[0].__valid, "A missing property must be flagged as invalid");
}

/// @desc Reverse() does nothing when no animation is configured.
function test_guard_reverse_without_animation()
{
	var _tween = __sc_test_tween({ x: 0 });
	_tween.Reverse();

	AssertFalse(_tween.IsReversed() );
}

/// @desc The target cannot be swapped while the tween is running, only after Stop().
function test_guard_target_change_while_playing()
{
	var _old_target = { x: 0 };
	var _new_target = { x: 0 };
	var _tween = __sc_test_tween(_old_target).To(1, "x", 100).Play();

	_tween.Target(_new_target);
	_old_target.x = 7;

	AssertEqual(_tween.__target.x, 7, "The target must not change while playing");

	_tween.Stop();
	_tween.Target(_new_target);
	_new_target.x = 9;

	AssertEqual(_tween.__target.x, 9, "Stop() must allow changing the target");
}

#endregion

#region RELATIVE VALUES

/// @desc A plain numeric string is treated as an absolute value.
function test_relative_absolute_string()
{
	AssertNear(__sc_test_resolved_finish(10, "42"), 42, 0.0001);
	AssertNear(__sc_test_resolved_finish(10, "2.5"), 2.5, 0.0001, "Decimals must be preserved");
}

/// @desc A real value passes through untouched.
function test_relative_absolute_real()
{
	AssertNear(__sc_test_resolved_finish(10, 42), 42, 0.0001);
}

/// @desc "+n" adds to the captured start value.
function test_relative_add()
{
	AssertNear(__sc_test_resolved_finish(5, "+10"), 15, 0.0001);
}

/// @desc "-n" subtracts from the captured start value.
function test_relative_subtract()
{
	AssertNear(__sc_test_resolved_finish(5, "-10"), -5, 0.0001);
}

/// @desc "*n" multiplies the start value, decimals included.
function test_relative_multiply_decimal()
{
	AssertNear(__sc_test_resolved_finish(10, "*1.5"), 15, 0.0001, "Decimals must not be stripped");
}

/// @desc "/n" divides the start value, decimals included.
function test_relative_divide_decimal()
{
	AssertNear(__sc_test_resolved_finish(10, "/2.5"), 4, 0.0001);
}

/// @desc "^n" raises the start value to the given power.
function test_relative_power()
{
	AssertNear(__sc_test_resolved_finish(3, "^2"), 9, 0.0001);
}

/// @desc "%n" applies the modulo operation to the start value.
function test_relative_modulo()
{
	AssertNear(__sc_test_resolved_finish(7, "%2"), 1, 0.0001);
}

/// @desc An unparsable relative value falls back to the base value.
function test_relative_invalid_falls_back()
{
	AssertNear(__sc_test_resolved_finish(5, "+abc"), 5, 0.0001);
}

/// @desc Division and modulo by zero fall back to the base value.
function test_relative_zero_divisor_falls_back()
{
	AssertNear(__sc_test_resolved_finish(5, "/0"), 5, 0.0001);
	AssertNear(__sc_test_resolved_finish(5, "%0"), 5, 0.0001);
}

/// @desc Refresh() re-resolves relative values against the current start value.
function test_relative_recalculates_on_refresh()
{
	var _target = { x: 10 };
	var _tween = __sc_test_tween(_target).To(0.1, "x", "+5");

	_tween.Refresh();
	AssertNear(_tween.__properties[0].__finish, 15, 0.0001);

	_target.x = 20;
	_tween.Refresh();
	AssertNear(_tween.__properties[0].__finish, 25, 0.0001, "Relative values must be recalculated from the raw configuration");
}

#endregion

#region TAGS

/// @desc Tags are stored and queryable.
function test_tag_add_and_has()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("ui", "menu");

	AssertEqual(array_length(_tween.__tags), 2);
	AssertTrue(_tween.HasTag("ui") );
	AssertTrue(_tween.HasTag("menu") );
	AssertFalse(_tween.HasTag("hud") );
}

/// @desc Adding the same tag twice keeps a single entry.
function test_tag_ignores_duplicates()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("ui", "ui", "ui");

	AssertEqual(array_length(_tween.__tags), 1);
}

/// @desc PauseTag()/ResumeTag() only affect tagged tweens.
function test_tag_pause_and_resume()
{
	var _tagged = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("ui").Play();
	var _other = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("world").Play();

	SCMaster.PauseTag("ui");
	AssertTrue(_tagged.IsPaused(), "The tagged tween must pause");
	AssertTrue(_other.IsPlaying(), "Untagged tweens must keep running");

	SCMaster.ResumeTag("ui");
	AssertTrue(_tagged.IsPlaying(), "The tagged tween must resume");
}

/// @desc StopTag() only affects tagged tweens.
function test_tag_stop()
{
	var _tagged = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("ui").Play();
	var _other = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("world").Play();

	SCMaster.StopTag("ui");
	AssertTrue(_tagged.IsFinished(), "The tagged tween must stop");
	AssertTrue(_other.IsPlaying(), "Untagged tweens must keep running");
}

/// @desc DestroyTag() unregisters only the tagged tweens.
function test_tag_destroy()
{
	var _tagged = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("ui").Play();
	var _other = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("world").Play();

	SCMaster.DestroyTag("ui");
	AssertFalse(_tagged.IsValid(), "The tagged tween must be destroyed");
	AssertTrue(_other.IsValid(), "Untagged tweens must survive");
	AssertEqual(SCMaster.Count(), 1);
}

/// @desc TimeScaleTag() only changes the speed of tagged tweens.
function test_tag_time_scale()
{
	var _tagged = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("ui");
	var _other = __sc_test_tween({ x: 0 }).To(1, "x", 10).Tag("world");

	SCMaster.TimeScaleTag("ui", 4);

	AssertNear(_tagged.__time_scale, 4, 0.0001);
	AssertNear(_other.__time_scale, 1, 0.0001, "Untagged tweens keep their own scale");
}

#endregion

#region MANAGER

/// @desc Tweens register on creation and unregister on destruction.
function test_manager_counts_registered_tweens()
{
	var _start = SCMaster.Count();
	var _first = __sc_test_tween({ x: 0 }).To(1, "x", 10);
	var _second = __sc_test_tween({ x: 0 }).To(1, "x", 10);

	AssertEqual(SCMaster.Count(), _start + 2);

	_first.Destroy();
	AssertEqual(SCMaster.Count(), _start + 1);

	_second.Destroy();
	AssertEqual(SCMaster.Count(), _start);
}

/// @desc The shared clock runs only while at least one tween is registered.
function test_manager_clock_follows_registrations()
{
	SCMaster.DestroyAll();
	AssertFalse(SCMaster.IsClockRunning(), "The clock must stop when no tweens remain");

	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);
	AssertTrue(SCMaster.IsClockRunning(), "Registering a tween must start the clock");

	_tween.Destroy();
	AssertFalse(SCMaster.IsClockRunning(), "Destroying the last tween must stop the clock");
}

/// @desc StopAll() stops every registered tween without destroying them.
function test_manager_stop_all()
{
	var _first = __sc_test_tween({ x: 0 }).To(1, "x", 10).Play();
	var _second = __sc_test_tween({ x: 0 }).To(1, "x", 10).Play();

	SCMaster.StopAll();

	AssertTrue(_first.IsFinished() );
	AssertTrue(_second.IsFinished() );
	AssertTrue(_first.IsValid(), "StopAll() must not destroy the tweens");
}

/// @desc DestroyAll() releases every registered tween.
function test_manager_destroy_all()
{
	var _first = __sc_test_tween({ x: 0 }).To(1, "x", 10).Play();
	var _second = __sc_test_tween({ x: 0 }).To(1, "x", 10).Play();

	SCMaster.DestroyAll();

	AssertEqual(SCMaster.Count(), 0);
	AssertFalse(_first.IsValid() );
	AssertFalse(_second.IsValid() );
	AssertFalse(SCMaster.IsClockRunning() );
}

/// @desc The global time scale round-trips and never becomes negative.
function test_manager_global_time_scale()
{
	SCMaster.SetGlobalTimeScale(0.5);
	AssertNear(SCMaster.GetGlobalTimeScale(), 0.5, 0.0001);

	SCMaster.SetGlobalTimeScale(-3);
	AssertNear(SCMaster.GetGlobalTimeScale(), 0, 0.0001, "Negative scales must clamp to zero");

	SCMaster.SetGlobalTimeScale(1);
}

/// @desc PauseAll()/ResumeAll() toggle every registered tween.
function test_manager_pause_and_resume_all()
{
	var _first = __sc_test_tween({ x: 0 }).To(1, "x", 10).Play();
	var _second = __sc_test_tween({ x: 0 }).To(1, "x", 10).Play();

	SCMaster.PauseAll();
	AssertTrue(_first.IsPaused() );
	AssertTrue(_second.IsPaused() );

	SCMaster.ResumeAll();
	AssertTrue(_first.IsPlaying() );
	AssertTrue(_second.IsPlaying() );
}

#endregion

#region LIFECYCLE

/// @desc Destroy() can be called repeatedly without side effects.
function test_life_destroy_is_idempotent()
{
	var _start = SCMaster.Count();
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);

	_tween.Destroy();
	_tween.Destroy();

	AssertFalse(_tween.IsValid() );
	AssertEqual(SCMaster.Count(), _start, "Destroy() must unregister only once");
}

/// @desc Destroy() releases the target so the struct can be collected.
function test_life_destroy_releases_target()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);
	_tween.Destroy();

	AssertIsNoone(_tween.__target, "A destroyed tween must drop its target");
	AssertEqual(array_length(_tween.__properties), 0, "A destroyed tween must drop its properties");
	AssertEqual(array_length(_tween.__launch_data), 0);
	AssertEqual(array_length(_tween.__tags), 0);
}

/// @desc GetType() and the state queries stay coherent before Play().
function test_life_state_before_play()
{
	var _tween = __sc_test_tween({ x: 0 }).To(1, "x", 10);

	AssertEqual(_tween.GetType(), SC_TYPE.TO);
	AssertFalse(_tween.IsPlaying() );
	AssertFalse(_tween.IsPaused() );
	AssertFalse(_tween.IsFinished(), "A stopped tween that never played is still startable");
	AssertTrue(_tween.IsValid() );
}

#endregion

#region ANIMATION (async)

// Async cases cannot capture local variables in their callbacks: Crispy binds `self`
// to the case and the closures are invoked from other scopes. Per-case state lives in
// `self.sc` so both the builder and every callback can reach it.

/// @desc To() reaches the exact end value and reports itself as finished.
function test_anim_to_reaches_exact_end_async()
{
	self.sc = { target: { x: 0 } };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.1, "x", 100).Play();

	WaitStep(function()
	{
		var _tween = self.sc.tween;
		if (!_tween.IsFinished() ) return false;

		AssertEqual(self.sc.target.x, 100, "The final value must be exact");
		AssertNear(_tween.GetPhaseProgress(), 1, 0.0001);
		AssertNear(_tween.GetProgress(), 1, 0.0001);

		_tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc A tween with destroy_on_finish destroys itself and leaves the manager empty.
function test_anim_autodestroy_on_finish_async()
{
	self.sc = { target: { x: 0 } };
	self.sc.tween = new SCurve(SCURVE.LINEAR, true).Target(self.sc.target).To(0.1, "x", 10).Play();

	WaitStep(function()
	{
		if (self.sc.tween.IsValid() ) return false;

		AssertEqual(self.sc.target.x, 10, "The end value must be applied before destroying");
		AssertFalse(self.sc.tween.IsPlaying() );
		return true;
	}).Timeout(10, "seconds");
}

/// @desc Disabling auto-destroy keeps the tween alive and valid after finishing.
function test_anim_survives_finish_without_autodestroy_async()
{
	self.sc = { target: { x: 0 } };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.1, "x", 10).Play();

	WaitStep(function()
	{
		if (!self.sc.tween.IsFinished() ) return false;

		AssertTrue(self.sc.tween.IsValid(), "The tween must remain usable");
		AssertEqual(self.sc.target.x, 10);

		self.sc.tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc Patrol walks go -> wait -> back, fires each callback once and returns to the start value.
function test_anim_patrol_callbacks_and_return_async()
{
	self.sc = { target: { x: 0 }, waits: 0, backs: 0, order: "" };

	self.sc.tween = __sc_test_tween(self.sc.target)
		.Patrol(0.08, 0.05, 0.02, "x", 100)
		.OnWait(method(self, function() { self.sc.waits++; self.sc.order += "w"; }) )
		.OnBack(method(self, function() { self.sc.backs++; self.sc.order += "b"; }) )
		.Play();

	WaitStep(function()
	{
		if (!self.sc.tween.IsFinished() ) return false;

		AssertEqual(self.sc.waits, 1, "OnWait must fire once");
		AssertEqual(self.sc.backs, 1, "OnBack must fire once");
		AssertEqual(self.sc.order, "wb", "The wait phase must precede the back phase");
		AssertNear(self.sc.target.x, 0, 0.0001, "Patrol must return to the start value");
		AssertNear(self.sc.tween.GetProgress(), -1, 0.0001);

		self.sc.tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc Repeat(2) plays exactly two cycles.
function test_anim_repeat_two_cycles_async()
{
	self.sc = { target: { x: 0 } };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.05, "x", 10).Repeat(2).Play();

	WaitStep(function()
	{
		if (!self.sc.tween.IsFinished() ) return false;

		AssertEqual(self.sc.tween.GetRepeatCount(), 2, "Repeat(2) must complete two cycles");
		AssertEqual(self.sc.target.x, 10);

		self.sc.tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc An infinite repeat keeps cycling and never finishes on its own.
function test_anim_repeat_infinite_async()
{
	self.sc = { target: { x: 0 } };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.02, "x", 10).Repeat().Play();

	WaitStep(function()
	{
		if (self.sc.tween.GetRepeatCount() < 1) return false;

		AssertFalse(self.sc.tween.IsFinished(), "An infinite repeat must never finish");
		AssertTrue(self.sc.tween.IsValid() );

		self.sc.tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc Pausing freezes the values and resuming continues the animation.
function test_anim_pause_and_resume_async()
{
	self.sc = { target: { x: 0 }, step: 0, frozen: -1 };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.3, "x", 100).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				self.sc.tween.Pause();
				AssertTrue(self.sc.tween.IsPaused() );
				self.sc.frozen = self.sc.target.x;
				self.sc.step = 1;
				return false;

			case 1:
				AssertNear(self.sc.target.x, self.sc.frozen, 0.0001, "A paused tween must not advance");
				self.sc.step = 2;
				return false;

			case 2:
				AssertNear(self.sc.target.x, self.sc.frozen, 0.0001, "A paused tween must not advance");
				self.sc.tween.Resume();
				AssertTrue(self.sc.tween.IsPlaying() );
				self.sc.step = 3;
				return false;

			case 3:
				if (!self.sc.tween.IsFinished() ) return false;

				AssertEqual(self.sc.target.x, 100, "The tween must resume and finish");
				self.sc.tween.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc Stop() halts the tween, and Play() restarts it from the beginning.
function test_anim_stop_and_restart_async()
{
	self.sc = { target: { x: 0 }, step: 0, stopped_at: -1 };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.2, "x", 100).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				if (self.sc.target.x <= 0) return false;

				self.sc.tween.Stop();
				AssertTrue(self.sc.tween.IsFinished(), "Stop() must finish the tween");
				self.sc.stopped_at = self.sc.target.x;
				self.sc.step = 1;
				return false;

			case 1:
				AssertNear(self.sc.target.x, self.sc.stopped_at, 0.0001, "A stopped tween must not advance");
				self.sc.tween.Play();
				AssertTrue(self.sc.tween.IsPlaying(), "Play() must restart a stopped tween");
				self.sc.step = 2;
				return false;

			case 2:
				if (!self.sc.tween.IsFinished() ) return false;

				AssertEqual(self.sc.target.x, 100, "The restarted tween must reach its end value");
				self.sc.tween.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc Reverse() while playing sends the tween back to its start value.
function test_anim_reverse_midway_async()
{
	self.sc = { target: { x: 0 }, step: 0 };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.3, "x", 100).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				if (self.sc.target.x <= 0) return false;

				self.sc.tween.Reverse();
				AssertTrue(self.sc.tween.IsReversed() );
				self.sc.step = 1;
				return false;

			case 1:
				if (!self.sc.tween.IsFinished() ) return false;

				AssertNear(self.sc.target.x, 0, 0.0001, "A reversed tween must return to its start value");
				AssertNear(self.sc.tween.GetProgress(), -1, 0.01, "A finished reverse tween reports full negative progress");
				self.sc.tween.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc TimeScale(0) freezes the animation until the scale is restored.
function test_anim_time_scale_zero_freezes_async()
{
	self.sc = { target: { x: 0 }, step: 0 };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.2, "x", 100).TimeScale(0).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				self.sc.step = 1;
				return false;

			case 1:
				AssertEqual(self.sc.target.x, 0, "A zero time scale must freeze the tween");
				self.sc.step = 2;
				return false;

			case 2:
				AssertEqual(self.sc.target.x, 0, "A zero time scale must keep the tween frozen");
				self.sc.tween.TimeScale(1);
				self.sc.step = 3;
				return false;

			case 3:
				if (!self.sc.tween.IsFinished() ) return false;

				AssertEqual(self.sc.target.x, 100, "The tween must continue once the scale is restored");
				self.sc.tween.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc Delay() postpones the animation and fires OnDelay once.
function test_anim_delay_defer_start_async()
{
	self.sc = { target: { x: 0 }, step: 0, delays: 0 };

	self.sc.tween = __sc_test_tween(self.sc.target)
		.Delay(0.3)
		.To(0.05, "x", 100)
		.OnDelay(method(self, function() { self.sc.delays++; }) )
		.Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				AssertTrue(self.sc.tween.IsDelaying(), "The tween must be delaying right after Play()");
				AssertEqual(self.sc.target.x, 0, "Nothing must move during the delay");
				self.sc.step = 1;
				return false;

			case 1:
				if (!self.sc.tween.IsFinished() ) return false;

				AssertEqual(self.sc.delays, 1, "OnDelay must fire once");
				AssertEqual(self.sc.target.x, 100);
				self.sc.tween.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc Launch() starts a queued tween when the parent finishes.
function test_anim_launch_on_finish_async()
{
	self.sc = { parent_target: { x: 0 }, child_target: { x: 0 }, step: 0 };

	self.sc.child = __sc_test_tween(self.sc.child_target).To(0.05, "x", 50);
	self.sc.parent = __sc_test_tween(self.sc.parent_target).To(0.05, "x", 10).Launch(self.sc.child).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				if (!self.sc.parent.IsFinished() ) return false;

				AssertTrue(self.sc.child.IsPlaying() || self.sc.child.IsFinished(), "The child must be launched on finish");
				self.sc.step = 1;
				return false;

			case 1:
				if (!self.sc.child.IsFinished() ) return false;

				AssertEqual(self.sc.parent_target.x, 10);
				AssertEqual(self.sc.child_target.x, 50, "The child must reach its own end value");

				self.sc.child.Destroy();
				self.sc.parent.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc Launch(tween, cycle) starts a queued tween on a specific cycle.
function test_anim_launch_on_repeat_async()
{
	self.sc = { parent_target: { x: 0 }, child_target: { x: 0 }, step: 0 };

	self.sc.child = __sc_test_tween(self.sc.child_target).To(0.05, "x", 50);
	self.sc.parent = __sc_test_tween(self.sc.parent_target).To(0.05, "x", 10).Repeat(2).Launch(self.sc.child, 1).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				if (self.sc.parent.GetRepeatCount() < 1) return false;

				AssertTrue(self.sc.child.IsPlaying() || self.sc.child.IsFinished(), "The child must be launched on the first cycle");
				AssertFalse(self.sc.parent.IsFinished(), "The parent must still be cycling");
				self.sc.step = 1;
				return false;

			case 1:
				if (!self.sc.child.IsFinished() ) return false;

				AssertEqual(self.sc.child_target.x, 50);

				self.sc.child.Destroy();
				self.sc.parent.Destroy();
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

/// @desc OnStart and OnUpdate fire with the right arguments.
function test_anim_start_and_update_callbacks_async()
{
	self.sc = { target: { x: 0 }, starts: 0, updates: 0, last: -1 };

	self.sc.tween = __sc_test_tween(self.sc.target)
		.To(0.08, "x", 10)
		.OnStart(method(self, function() { self.sc.starts++; }) )
		.OnUpdate(method(self, function(_progress) { self.sc.updates++; self.sc.last = _progress; }) )
		.Play();

	WaitStep(function()
	{
		if (!self.sc.tween.IsFinished() ) return false;

		AssertEqual(self.sc.starts, 1, "OnStart must fire once");
		AssertTrue(self.sc.updates > 0, "OnUpdate must fire every frame");
		AssertNear(self.sc.last, 1, 0.0001, "OnUpdate must receive the applied progress");

		self.sc.tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc Relative end values resolve to absolute values when the tween starts.
function test_anim_relative_end_value_async()
{
	self.sc = { target: { x: 10 } };
	self.sc.tween = __sc_test_tween(self.sc.target).To(0.05, "x", "*1.5").Play();

	WaitStep(function()
	{
		if (!self.sc.tween.IsFinished() ) return false;

		AssertEqual(self.sc.target.x, 15, "A relative end value must resolve against the captured start");

		self.sc.tween.Destroy();
		return true;
	}).Timeout(10, "seconds");
}

/// @desc A tween destroys itself when its target instance disappears mid-animation.
function test_anim_target_destroyed_autodestroys_async()
{
	self.sc = { step: 0, dummy: __sc_test_dummy_instance() };

	AssertIsNotNoone(self.sc.dummy, "The dummy target instance must exist");

	self.sc.tween = new SCurve(SCURVE.LINEAR, true).Target(self.sc.dummy).To(5, "image_alpha", 0.5).Play();

	WaitStep(function()
	{
		switch (self.sc.step)
		{
			case 0:
				AssertTrue(self.sc.tween.IsValid() );

				with (self.sc.dummy) instance_destroy();
				self.sc.step = 1;
				return false;

			case 1:
				AssertFalse(self.sc.tween.IsValid(), "The tween must destroy itself when the target disappears");
				AssertFalse(self.sc.tween.IsPlaying() );
				return true;
		}

		return false;
	}).Timeout(10, "seconds");
}

#endregion
