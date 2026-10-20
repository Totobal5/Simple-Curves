/// @desc Singleton manager used to control all SCurve animations.
function SCMaster()
{
	/// @ignore
	/// @type {Array<Struct.SCurve>}
	/// @desc Global list of all active SCurve instances for management and control.
	static __list = [];

	/// @ignore
	/// @type {Struct<Real, Struct.SCurve>}
	/// @desc Registry of SCurve instances by their unique id, used for O(1) unregistration.
	static __map = {};

	/// @ignore
	/// @type {Real}
	static __time_scale = 1.0;

	/// @ignore
	/// @type {Real}
	/// @desc Delta time (in seconds) of the current frame, shared by every SCurve.
	static __delta = 0;

	/// @ignore
	/// @type {Real}
	/// @desc Previous frame delta, used to smooth lag spikes.
	static __delta_previous = 0;

	/// @ignore
	/// @type {Bool}
	/// @desc Flag indicating whether delta is being restored after a lag spike.
	static __delta_restored = false;

	/// @ignore
	/// @type {Real}
	/// @desc The maximum allowed delta time to prevent lag spikes.
	static __delta_max = 1 / SC_MIN_DELTA_FPS;

	/// @ignore
	/// @desc Updates the shared delta once per frame. Called by the manager clock.
	static __TickClock = function()
	{
		var _previous_delta = SCMaster.__delta;
		var _current_delta = delta_time / 1000000;

		if (_current_delta > SCMaster.__delta_max)
		{
			// If delta time is too large (FPS drop), use a safe value to avoid abrupt animation jumps.
			SCMaster.__delta = SCMaster.__delta_restored ? SCMaster.__delta_max : _previous_delta;
			SCMaster.__delta_restored = true;
		}
		else
		{
			SCMaster.__delta = _current_delta;
			SCMaster.__delta_restored = false;
		}
	}

	/// @ignore
	/// @type {Id.TimeSource}
	/// @desc Single clock that drives every SCurve. Runs while at least one animation is registered.
	static __clock = time_source_create(time_source_game, 1, time_source_units_frames, __TickClock, [], -1, time_source_expire_after);

	/// @ignore
	/// @desc Starts the shared clock if it is not already running.
	static __StartClock = function()
	{
		if (!time_source_exists(__clock) ) return self;

		var _state = time_source_get_state(__clock);
		if (_state == time_source_state_initial || _state == time_source_state_stopped)
		{
			__delta_previous = delta_time / 1000000;
			__delta = __delta_previous;
			__delta_restored = false;
			time_source_start(__clock);
		}

		return self;
	}

	/// @ignore
	/// @desc Stops the shared clock when no animations remain registered.
	static __StopClock = function()
	{
		if (time_source_exists(__clock) ) time_source_stop(__clock);
		return self;
	}

	/// @desc Returns the shared delta time of the current frame, in seconds.
	/// @return {Real} Delta time in seconds.
	static GetDelta = function()
	{
		return __delta;
	}

	/// @ignore
	/// @type {Bool}
	/// @desc Runtime override of SC_LOG_ERRORS, used to silence expected errors.
	static __log_errors = SC_LOG_ERRORS;

	/// @ignore
	/// @type {Bool}
	/// @desc Runtime override of SC_FATAL_ERRORS, used to keep expected errors non-fatal.
	static __fatal_errors = SC_FATAL_ERRORS;

	/// @desc Overrides SC_LOG_ERRORS at runtime. Handy for test runs and release builds.
	/// @param {Bool} _enabled Whether errors should be written to the output.
	/// @return {Struct.SCMaster} this manager
	static SetLogErrors = function(_enabled)
	{
		__log_errors = _enabled;
		return self;
	}

	/// @desc Returns whether errors are currently written to the output.
	/// @return {Bool} True when errors are logged.
	static GetLogErrors = function()
	{
		return __log_errors;
	}

	/// @desc Overrides SC_FATAL_ERRORS at runtime. Handy for test runs and release builds.
	/// @param {Bool} _enabled Whether an error should halt the game.
	/// @return {Struct.SCMaster} this manager
	static SetFatalErrors = function(_enabled)
	{
		__fatal_errors = _enabled;
		return self;
	}

	/// @desc Returns whether errors currently halt the game.
	/// @return {Bool} True when errors are fatal.
	static GetFatalErrors = function()
	{
		return __fatal_errors;
	}

	/// @desc Returns whether the shared clock is currently running.
	/// @return {Bool} True while the clock is ticking.
	static IsClockRunning = function()
	{
		if (!time_source_exists(__clock) ) return false;

		var _state = time_source_get_state(__clock);
		return (_state == time_source_state_active || _state == time_source_state_paused);
	}
	
	/// @ignore
	/// @desc Registers an animation in the global list.
	/// @param {Struct.SCurve} scurve_instance The SCurve instance to register.
	static __Register = function(_scurve_instance)
	{
		_scurve_instance.__slot = array_length(__list);
		array_push(__list, _scurve_instance);
		variable_struct_set(__map, string(_scurve_instance.__id), _scurve_instance);

		__StartClock();

		return self;
	}
	
	/// @ignore
	/// @desc Removes an animation from the global list.
	/// @param {Struct.SCurve} scurve_instance The SCurve instance to remove.
	static __Unregister = function(_scurve_instance)
	{
		var _key = string(_scurve_instance.__id);
		if (!variable_struct_exists(__map, _key) ) return self;

		variable_struct_remove(__map, _key);

		// Swap-remove keeps unregistration O(1) instead of shifting the whole list.
		var _slot = _scurve_instance.__slot;
		var _last = array_length(__list) - 1;

		if (_slot >= 0 && _slot <= _last)
		{
			if (_slot != _last)
			{
				__list[_slot] = __list[_last];
				__list[_slot].__slot = _slot;
			}

			array_delete(__list, _last, 1);
		}

		_scurve_instance.__slot = -1;

		if (array_length(__list) == 0) __StopClock();

		return self;
	}
	
	/// @desc Pauses all active animations.
	static PauseAll = function()
	{
		for (var i = array_length(__list) - 1; i >= 0; i--) __list[i].Pause();
		return self;
	}

	/// @desc Resumes all paused animations.
	static ResumeAll = function()
	{
		for (var i = array_length(__list) - 1; i >= 0; i--) __list[i].Resume();
		return self;
	}

	/// @desc Stops all active animations. They can be restarted with Play().
	static StopAll = function()
	{
		for (var i = array_length(__list) - 1; i >= 0; i--) __list[i].Stop();
		return self;
	}

	/// @desc Destroys every registered animation and releases its resources.
	static DestroyAll = function()
	{
		// Destroy() unregisters, so iterate from the end while the list shrinks.
		for (var i = array_length(__list) - 1; i >= 0; i--) __list[i].Destroy();
		return self;
	}

	/// @desc Returns how many animations are currently registered.
	/// @return {Real} Number of registered animations.
	static Count = function()
	{
		return array_length(__list);
	}
	
	/// @desc Sets a global time scale for all animations.
	/// @param {Real} scale Speed multiplier (1=normal, 0.5=half, 2=double).
	static SetGlobalTimeScale = function(_scale)
	{
		__time_scale = max(0, _scale);
		return self;
	}
	
	/// @desc Gets the current global time scale.
	/// @return {Real} The global time scale.
	static GetGlobalTimeScale = function()
	{
		return __time_scale;
	}

	/// @desc Pauses all animations that contain the specified tag.
	/// @param {String} tag The tag to match.
	static PauseTag = function(_tag)
	{
		for (var i = array_length(__list) - 1; i >= 0; i--)
		{
			var _scurve = __list[i];
			if (_scurve.HasTag(_tag) ) _scurve.Pause();
		}

		return self;
	}
	
	/// @desc Resumes all animations that contain the specified tag.
	/// @param {String} tag The tag to match.
	static ResumeTag = function(_tag)
	{
		for (var i = array_length(__list) - 1; i >= 0; i--)
		{
			var _scurve = __list[i];
			if (_scurve.HasTag(_tag) ) _scurve.Resume();
		}

		return self;
	}
	
	/// @desc Stops all animations that contain the specified tag.
	/// @param {String} tag The tag to match.
	static StopTag = function(_tag)
	{
		for (var i = array_length(__list) - 1; i >= 0; i--)
		{
			var _scurve = __list[i];
			if (_scurve.HasTag(_tag) ) _scurve.Stop();
		}

		return self;
	}
	
	/// @desc Destroys all animations that contain the specified tag.
	/// @param {String} tag The tag to match.
	static DestroyTag = function(_tag)
	{
		for (var i = array_length(__list) - 1; i >= 0; i--)
		{
			var _scurve = __list[i];
			if (_scurve.HasTag(_tag) ) _scurve.Destroy();
		}

		return self;
	}
	
	/// @desc Sets the time scale for all animations with a specific tag.
	/// @param {String} tag The tag to match.
	/// @param {Real} scale The time scale to apply.
	static TimeScaleTag = function(_tag, _scale)
	{
		for (var i = array_length(__list) - 1; i >= 0; i--)
		{
			var _scurve = __list[i];
			if (_scurve.HasTag(_tag) ) _scurve.TimeScale(_scale);
		}

		return self;
	}
}

/// @desc Creates and manages a curve-based animation.
/// @param {Enum.SCURVE} curve The Animation Curve channel name to use.
/// @param {Bool} [destroy_on_finish=true] (Optional) Whether the animation should auto-destroy when it finishes.
function SCurve(_curve, _destroy_on_finish=true) constructor
{
	/// @ignore
	/// @type {Real}
	/// @desc Slot index of this animation in the manager list (-1 when not registered).
	__slot = -1;

	/// @ignore
	/// @type {Bool}
	/// @desc Flag indicating whether this animation has been destroyed.
	__destroyed = false;

	/// @ignore
	/// @type {Bool}
	/// @desc True when the captured start values belong to a previous target.
	__needs_init = false;

	/// @ignore
	/// @type {Real}
	/// @desc The unique identifier counter for SCurve instances.
	static __id_count = 0;

	#region PROPERTIES

	/// @ignore
	/// @type {Real}
	/// @desc The unique identifier for this SCurve instance.
	__id = __id_count;
	__id_count++;

	/// @ignore
	/// @type {String}
	/// @desc The type of animation: SC_TYPE.TO or SC_TYPE.PATROL.
	__type = SC_TYPE.NONE;

	/// @ignore
	/// @type {Real}
	/// @desc The initial delay before the animation starts.
	__delay = 0;

	/// @ignore 
	/// @type {Real}
	/// @desc Runtime countdown used for the configured delay.
	__delay_time = 0;

	/// @ignore
	/// @type {Real}
	/// @desc The total duration of the animation.
	__duration = 1;

	/// @ignore
	/// @type {Real}
	/// @desc Runtime elapsed time for the current phase.
	__phase_time = 0;

	/// @ignore
	/// @type {Real}
	/// @desc Runtime duration for the current phase.
	__phase_duration = 1;

	/// @ignore
	/// @type {Real}
	/// @desc Current progress of the animation (0 to 1).
	__progress = 0;

	/// @ignore
	/// @type {Real}
	/// @desc Time scale for this animation.
	__time_scale =	1.0;

	/// @ignore 
	/// @type {Bool}
	/// @desc Flag for the initial delay state.
	__is_delaying = false;

	/// @ignore 
	/// @type {Bool}
	/// @desc Flag for reverse mode.
	__is_reversed = false;

	/// @ignore 
	/// @type {Bool}
	/// @desc Flag for auto-destruction (default: true).
	__destroy_on_finish = _destroy_on_finish;

	/// @ignore
	/// @type {Array<String>}
	/// @desc Array used to store tags.
	__tags = [];
	
	/// @ignore 
	/// @type {Id.Instance | Struct}
	/// @desc The instance or struct to animate.
	__target = noone;

	/// @ignore 
	/// @desc Cached target kind for faster property access.
	__target_is_struct = false;

	/// @ignore
	/// @type {Array<Struct.SCurve.__Property>}
	/// @desc One __Property struct per animated variable.
	__properties = [];
	
	/// @ignore
	/// @desc Duration of the backward phase.
	__duration_back = 0;

	/// @ignore
	/// @desc Delay between the forward and backward phases.
	__delay_between = 0;
	
	/// @ignore 
	/// @desc States: SC_PATROL_MODE.GO, SC_PATROL_MODE.WAIT, SC_PATROL_MODE.BACK
	__patrol_state = SC_PATROL_MODE.GO;
	
	/// @ignore
	/// @desc Total cycles to play. 1 = play once, -1 = infinite.
	__repeats = 1;

	/// @ignore
	/// @desc Completed repeat counter.
	__repeat_count = 0;

	/// @ignore
	/// @type {Array<{target: Struct.SCurve, on_repeat: Real}>}
	/// @desc Array of structs used to store animations to launch on specific repeats.
	__launch_data = [];

	/// @ignore
	/// @type {Enum.SCURVE}
	/// @desc Ease animation to use for this SCurve.
	__channel_index = _curve;
	
	/// @ignore
	/// @type {Struct.AnimCurveChannel}
	/// @desc Cached curve struct for faster evaluation.
	__channel_struct = animcurve_get_channel(Simple_Curves_Animation, __channel_index);

	/// @ignore 
	/// @desc Cached curve kind for the linear fast path.
	__channel_is_linear = (__channel_index == SCURVE.LINEAR);
	
	#endregion

	#region CALLBACKS

	/// @ignore
	/// @desc Callback triggered when the animation finishes. If repeats are set, it runs after the last repeat.
	__callback_finish = undefined;
	
	/// @ignore
	/// @desc Callback triggered when a Patrol enters its wait phase between forward and backward.
	__callback_wait = undefined;
	
	/// @ignore
	/// @desc Callback triggered when a Patrol completes the forward phase and starts the backward phase.
	__callback_back = undefined;
	
	/// @ignore
	/// @desc Callback triggered each time a repeat completes, receiving the current repeat number (starting at 1).
	/// @param {Real} repeat_count The repeat number that has just completed.
	__callback_repeat = undefined;

	/// @ignore
	/// @desc Callback triggered when the initial delay finishes, before the animation starts.
	__callback_delay = undefined;

	/// @ignore
	/// @desc Callback triggered right after the animation starts.
	__callback_start = undefined;

	/// @ignore
	/// @desc Callback triggered every frame after the values are applied, receiving the phase progress.
	/// @param {Real} progress The current phase progress (0-1).
	__callback_update = undefined;
	
	/// @ignore
	/// @type {Struct.TimeSource}
	/// @desc Time source used to drive the animation. Created below, once every static exists.
	__step = undefined;

	#endregion

	// By default, the target is the creator.
	Target(other);

	// Created here so every static (including __Tick) already exists when the time source binds to it.
	__step = time_source_create(time_source_game, 1, time_source_units_frames, method(self, __Tick), [], -1, time_source_expire_after);

	// Register this instance once it is fully configured.
	SCMaster.__Register(self);

	#region Privates

	/// @ignore
	/// @desc Internal constructor used to store data for each property to animate.
	/// @param {String} _name The name of the property to animate.
	/// @param {Any} _finish The target value for the property (real or relative string).
	static __Property = function(_name, _finish) constructor
	{
		if (!is_string(_name) || string_length(_name) == 0)
		{
			__scurve_error("Property name must be a non-empty string.");
			_name = "undefined";
		}

		/// @ignore
		/// @desc The name of the property to animate.
		__name = _name;

		/// @ignore
		/// @desc The hash of the property to animate.
		__hash = variable_get_hash(_name);

		/// @ignore 
		/// @desc The start value for the property.
		__start = 0;

		/// @ignore
		/// @desc The end value as configured by the user. May be a relative string such as "+100".
		__finish_raw = _finish;

		/// @ignore
		/// @desc The resolved end value for the property.
		__finish = _finish;

		/// @ignore
		/// @type {Bool}
		/// @desc False when the property does not exist on the target.
		__valid = false;
		
		/// @ignore
		/// @desc The start phase for the property.
		__phase_from = 0;

		/// @ignore
		/// @desc The end phase for the property.
		__phase_to = 0;

		/// @ignore
		/// @desc The delta between the start and end phase for the property.
		__phase_delta = 0;

		if (SC_LOG_ALERTS_PROPERTY) 
		{
			__scurve_alert($"Property '{_name}' configured with end value '{_finish}'. The start value will be captured when the animation begins.");
		}
	}

	/// @ignore
	/// @desc Main animation loop, executed every frame.
	static __Tick = function()
	{
		if (__destroyed) exit;

		// A destroyed target can never be updated again: release the animation instead of ticking forever.
		if (!__HasValidTarget() )
		{
			__scurve_alert("The animation target no longer exists. The animation was destroyed.");
			Destroy();
			exit;
		}

		// Apply global and local time scaling.
		var _scaled_delta = SCMaster.GetDelta() * __time_scale * SCMaster.GetGlobalTimeScale();
		var _animation_finished = false;

		#region DELAY HANDLING
		if (__is_delaying)
		{
			__delay_time -= _scaled_delta;
			if (__delay_time <= 0)
			{
				__is_delaying = false;
				// Add leftover delay time into the animation time to preserve precision.
				__phase_time += abs(__delay_time);

				// Trigger the delay callback if defined.
				if (is_callable(__callback_delay) ) __callback_delay();
			}
			
			exit; 
		}
		
		#endregion

		switch (__type)
		{
			// Single-cycle animation logic
			case SC_TYPE.TO:
				__phase_time += _scaled_delta;
				__progress = __phase_time / __phase_duration;
				
				// Time-based completion condition.
				if (__progress >= 1)
				{
					// Ensure the final value is exact.
					__progress = 1; 
					_animation_finished = true;
				}
				
				__Apply(__progress, __channel_struct);
			break;
			
			// Patrol mode logic
			case SC_TYPE.PATROL:
				switch (__patrol_state)
				{
					case SC_PATROL_MODE.GO:
						__phase_time += _scaled_delta;
						__progress = __phase_time / __phase_duration;
						if (__progress >= 1)
						{
							// Carry the leftover time into the wait phase so phase transitions stay exact.
							var _go_overflow = __phase_time - __phase_duration;
							__progress = 1;
							__Apply(1, __channel_struct);

							__patrol_state = SC_PATROL_MODE.WAIT;
							__phase_time = _go_overflow;
							if (is_callable(__callback_wait) ) __callback_wait();
						}
						else
						{
							__Apply(__progress, __channel_struct);
						}
					break;
					
					case SC_PATROL_MODE.WAIT:
						__phase_time += _scaled_delta;
						if (__phase_time >= __delay_between)
						{
							var _wait_overflow = __phase_time - __delay_between;
							__SetPatrolPhase(SC_PATROL_MODE.BACK, false, 1);
							__phase_time = _wait_overflow;
							if (is_callable(__callback_back) ) __callback_back();
						}
					break;
					
					case SC_PATROL_MODE.BACK:
						__phase_time += _scaled_delta;
						__progress = __phase_time / __phase_duration;
						if (__progress >= 1)
						{
							__progress = 1;
							_animation_finished = true;
						}
						__Apply(__progress, __channel_struct);
					break;
				}
			break;
		}

		// Notify the update callback with the progress that was just applied.
		if (is_callable(__callback_update) ) __callback_update(__progress);

		// Repeat logic at the end of the cycle
		if (!_animation_finished) exit;

		__repeat_count++;

		// Trigger the repeat callback if defined.
		if (is_callable(__callback_repeat) ) __callback_repeat(__repeat_count);

		// Reached the repeat limit (or not repeating at all)?
		if (__repeats != -1 && __repeat_count >= __repeats)
		{
			if (is_callable(__callback_finish) ) __callback_finish();

			// Launch any SCurves that were set to launch at the end of this animation.
			__LaunchPending(SC_LAUNCH_ON_FINISH);

			// Decide whether to destroy or stop.
			if (__destroy_on_finish) { Destroy(); } else { Stop(); }
			exit;
		}

		// Launch any SCurves that were set to launch on this repeat, then start the next cycle.
		__LaunchPending(__repeat_count);
		__Reset();
	}
	

	/// @ignore
	/// @desc Applies the calculated value to target properties.
	static __Apply = function(_value, _channel)
	{
		var _eased_value = __channel_is_linear ? _value : animcurve_channel_evaluate(_channel, _value);

		var i = 0; repeat(array_length(__properties) )
		{
			var _prop = __properties[i++];

			// Properties that do not exist on the target are reported once in __InitProps.
			if (!_prop.__valid) continue;

			__SetTargetValue(_prop.__hash, _prop.__phase_from + (_prop.__phase_delta * _eased_value) );
		}
	}

	/// @ignore
	/// @desc Resets animation state for a new repeat.
	static __Reset = function()
	{
		__PreparePhase();
	}

	/// @ignore
	/// @desc Plays every queued animation registered for the given repeat index.
	/// @param {Real} _repeat_index Repeat index to match. SC_LAUNCH_ON_FINISH matches the end of the animation.
	static __LaunchPending = function(_repeat_index)
	{
		var i = 0; repeat(array_length(__launch_data) )
		{
			var _launch = __launch_data[i++];
			if (_launch.on_repeat != _repeat_index) continue;

			if (!_launch.target.IsValid() )
			{
				__scurve_alert("A queued animation was destroyed before it could be launched. Skipping.");
				continue;
			}

			_launch.target.Play();
		}
	}

	/// @ignore
	/// @desc Gets the current value of a property from the active target.
	/// @param {String} prop_hash The hash of the property to retrieve.
	static __GetTargetValue = function(_prop_hash)
	{
		if (!__HasValidTarget() ) return undefined;
		return struct_get_from_hash(__target, _prop_hash);
	}

	/// @ignore
	/// @desc Sets a property value on the active target.
	/// @param {String} _prop_hash The hash of the property to set.
	/// @param {Real} _value The value to set.
	static __SetTargetValue = function(_prop_hash, _value)
	{
		struct_set_from_hash(__target, _prop_hash, _value);
	}

	/// @ignore
	/// @desc Returns true while the target still exists, so animations never tick against a dead target.
	/// @return {Bool} True when the target is a live instance or a struct.
	static __HasValidTarget = function()
	{
		if (__target_is_struct) return is_struct(__target);
		return instance_exists(__target);
	}

	/// @ignore
	/// @desc Computes duration ratio for To based on real remaining distance.
	static __ComputeToPhaseRatio = function(_is_reversed_phase)
	{
		var _ratio = 0;
		var _has_ratio = false;

		var i = 0; repeat(array_length(__properties))
		{
			var _prop = __properties[i++];
			var _current = __GetTargetValue(_prop.__hash);

			if (!is_real(_current) || !is_real(_prop.__start) || !is_real(_prop.__finish) ) continue;

			var _target = _is_reversed_phase ? _prop.__start : _prop.__finish;
			var _full = abs(_prop.__finish - _prop.__start);
			if (_full <= 0) continue;
			
			var _remaining = abs(_target - _current);
			_ratio = max(_ratio, clamp(_remaining / _full, 0, 1));
			_has_ratio = true;
		}

		return _has_ratio ? _ratio : clamp(__progress, 0, 1);
	}

	/// @ignore
	/// @desc Computes duration ratio for Patrol based on real remaining distance.
	static __ComputePatrolPhaseRatio = function(_target_state)
	{
		var _ratio = 0;
		var _has_ratio = false;

		var i = 0; repeat(array_length(__properties) )
		{
			var _prop = __properties[i++];
			var _current = __GetTargetValue(_prop.__hash);
			var _is_forward = __is_reversed ? (_target_state == SC_PATROL_MODE.BACK) : (_target_state == SC_PATROL_MODE.GO);
			var _target = _is_forward ? _prop.__finish : _prop.__start;
			var _full_from = _is_forward ? _prop.__start : _prop.__finish;

			if (!is_real(_current) || !is_real(_target) || !is_real(_full_from)) continue;

			var _full = abs(_target - _full_from);
			if (_full <= 0) continue;

			var _remaining = abs(_target - _current);
			_ratio = max(_ratio, clamp(_remaining / _full, 0, 1));
			_has_ratio = true;
		}

		return _has_ratio ? _ratio : clamp(__progress, 0, 1);
	}

	/// @ignore
	/// @desc Configures the runtime phase for a To animation.
	static __SetToPhase = function(_is_reversed_phase, _from_current = false, _duration_ratio = 1)
	{
		var _ratio = clamp(_duration_ratio, 0, 1);
		__phase_time = 0;
		__phase_duration = max(SC_MIN_PHASE_DURATION, __duration * _ratio);
		__progress = 0;

		var i = 0; repeat(array_length(__properties))
		{
			var _prop = __properties[i++];
			_prop.__phase_from = _from_current ? __GetTargetValue(_prop.__hash) : (_is_reversed_phase ? _prop.__finish : _prop.__start);
			_prop.__phase_to = _is_reversed_phase ? _prop.__start : _prop.__finish;
			_prop.__phase_delta = _prop.__phase_to - _prop.__phase_from;
		}
	}

	/// @ignore
	/// @desc Configures the runtime phase for a Patrol animation.
	static __SetPatrolPhase = function(_state, _from_current = false, _duration_ratio = 1)
	{
		var _ratio = clamp(_duration_ratio, 0, 1);
		var _is_forward = __is_reversed ? (_state == SC_PATROL_MODE.BACK) : (_state == SC_PATROL_MODE.GO);
		__patrol_state = _state;
		__phase_time = 0;
		__phase_duration = max(SC_MIN_PHASE_DURATION, (_state == SC_PATROL_MODE.GO ? __duration : __duration_back) * _ratio);
		__progress = 0;

		var i = 0; repeat(array_length(__properties) )
		{
			var _prop = __properties[i++];
			_prop.__phase_from = _from_current ? __GetTargetValue(_prop.__hash) : (_is_forward ? _prop.__start : _prop.__finish);
			_prop.__phase_to = _is_forward ? _prop.__finish : _prop.__start;
			_prop.__phase_delta = _prop.__phase_to - _prop.__phase_from;
		}
	}

	/// @ignore
	/// @desc Prepares runtime phase values from the current configuration.
	static __PreparePhase = function()
	{
		__delay_time = __delay;
		__is_delaying = __delay_time > 0;

		switch (__type)
		{
			case SC_TYPE.TO:
				__SetToPhase(__is_reversed, false, 1);
			break;

			case SC_TYPE.PATROL:
				__SetPatrolPhase(SC_PATROL_MODE.GO, false, 1);
			break;
		}
	}
	
	/// @ignore
	/// @desc Parses a numeric string. Returns undefined when the string is not a number.
	/// @param {String} _string The string to parse.
	/// @return {Real|Undefined} The parsed number, or undefined.
	static __ParseReal = function(_string)
	{
		var _length = string_length(_string);
		if (_length == 0) return undefined;

		for (var i = 1; i <= _length; i++)
		{
			var _code = ord(string_char_at(_string, i) );
			var _is_digit = (_code >= 48 && _code <= 57);
			// 46 = ".", 43 = "+", 45 = "-"
			if (!_is_digit && _code != 46 && _code != 43 && _code != 45) return undefined;
		}

		var _value = real(_string);
		return is_nan(_value) ? undefined : _value;
	}

	/// @ignore
	/// @desc Resolves a configured end value against a base value.
	///       Numbers pass through untouched; strings are parsed as absolute numbers or as relative operations ("+10", "-3", "*2", "/2", "^2", "%2").
	/// @param {Any} _raw The configured end value.
	/// @param {Real} _base The value the relative operation applies to.
	/// @return {Real|Undefined} The resolved end value.
	static __ResolveEnd = function(_raw, _base)
	{
		if (!is_string(_raw) ) return _raw;

		var _operator = string_char_at(_raw, 1);
		if (string_pos(_operator, "+-*/^%") == 0) return __ParseReal(_raw);

		var _value = __ParseReal(string_delete(_raw, 1, 1) );
		if (is_undefined(_value) )
		{
			__scurve_error($"Invalid relative value '{_raw}'. A number was expected after '{_operator}'.");
			return _base;
		}

		switch (_operator)
		{
			case "+": return _base + _value;
			case "-": return _base - _value;
			case "*": return _base * _value;
			case "^": return power(_base, _value);

			case "/":
				if (_value == 0)
				{
					__scurve_error($"Division by zero in relative value '{_raw}'.");
					return _base;
				}

				return _base / _value;

			case "%":
				if (_value == 0)
				{
					__scurve_error($"Modulo by zero in relative value '{_raw}'.");
					return _base;
				}

				return _base mod _value;
		}

		// Fallback
		return _base;
	}

	/// @ignore
	/// @desc "Compiles" properties by reading start values and resolving relative values.
	static __InitProps = function()
	{
		if (!__HasValidTarget() )
		{
			__scurve_error("Cannot initialize the animation properties: the target does not exist.");
			return false;
		}

		var i = 0; repeat(array_length(__properties) )
		{
			var _prop = __properties[i++];
			_prop.__start = __GetTargetValue(_prop.__hash);

			if (is_undefined(_prop.__start) )
			{
				_prop.__valid = false;
				__scurve_error($"Property '{_prop.__name}' does not exist on the target.");
				continue;
			}

			_prop.__valid = true;

			// Always resolve from the raw configuration so Refresh() can recalculate relative values.
			_prop.__finish = __ResolveEnd(_prop.__finish_raw, _prop.__start);
		}

		__PreparePhase();

		return true;
	}
	
	#endregion
	
	#region PUBLIC API

	/// @desc Starts the animation.
	/// @return {Struct.SCurve} description
	static Play = function()
	{
		if (__destroyed)
		{
			__scurve_error("Cannot Play() a destroyed SCurve.");
			return self;
		}

		if (__type == SC_TYPE.NONE)
		{
			__scurve_error("Cannot Play() before configuring '.To()' or '.Patrol()'.");
			return self;
		}

		if (!__HasValidTarget() )
		{
			__scurve_error("Cannot Play() because the target does not exist.");
			return self;
		}

		if (!time_source_exists(__step) ) return self;

		var _time_state = time_source_get_state(__step);
		if (_time_state == time_source_state_initial || _time_state == time_source_state_stopped)
		{
			// Restart the cycle counter on every new run.
			__repeat_count = 0;

			// Capture start values on the first run and whenever the target changed.
			if (_time_state == time_source_state_initial || __needs_init)
			{
				if (!__InitProps() ) return self;

				__needs_init = false;
			}
			else
			{
				__PreparePhase();
			}

			time_source_start(__step);

			if (is_callable(__callback_start) ) __callback_start();
		}
		
		if (SC_LOG_ALERTS_PLAY) 
		{
			__scurve_alert($"Play() called while the time source was in state {_time_state}.");
		}
		
		return self;		
	}
	
	/// @desc Recaptures property start values from the current target.
	///       Useful for reusable SCurves where values may have changed.
	///       Must be called BEFORE Play() to take effect.
	/// @return {Struct.SCurve}
	static Refresh = function()
	{
		if (__destroyed)
		{
			__scurve_error("Cannot Refresh() a destroyed SCurve.");
			return self;
		}

		__repeat_count = 0;

		if (__InitProps() ) __needs_init = false;

		return self;
	}
	
	/// @desc Stops the animation.
	/// @return {Struct.SCurve} description    
	static Stop = function()
	{
		if (__destroyed) return self;
		if (!time_source_exists(__step) ) return self;
		time_source_stop(__step);

		return self;
	}
	
	/// @desc Pauses the animation.
	/// @return {Struct.SCurve} description    
	static Pause = function()
	{
		if (__destroyed) return self;
		if (!time_source_exists(__step) ) return self;
		if (time_source_get_state(__step) == time_source_state_active) time_source_pause(__step);

		return self;
	}
	
	/// @desc Resumes the animation.
	/// @return {Struct.SCurve} description
	static Resume = function()
	{
		if (__destroyed) return self;
		if (!time_source_exists(__step) ) return self;
		if (time_source_get_state(__step) == time_source_state_paused) time_source_resume(__step);

		return self;
	}

	/// @desc Destroys the animation and releases every resource it holds. Safe to call multiple times.
	/// @return {Struct.SCurve} this instance
	static Destroy = function()
	{
		if (__destroyed) return self;
		__destroyed = true;

		SCMaster.__Unregister(self);

		// Destroy the time source to free resources.
		if (time_source_exists(__step) )
		{
			time_source_destroy(__step);
			__step = undefined;
		}

		// Release every reference so the target and callbacks can be collected.
		__target = noone;
		__target_is_struct = false;
		__properties = [];
		__launch_data = [];
		__tags = [];
		__callback_finish = undefined;
		__callback_wait = undefined;
		__callback_back = undefined;
		__callback_repeat = undefined;
		__callback_delay = undefined;
		__callback_start = undefined;
		__callback_update = undefined;

		return self;
	}
	
	/// @desc Sets the target object/struct to animate.
	/// @param {Id.Instance | Struct} target The instance or struct to animate.
	/// @return {Struct.SCurve} description
	static Target = function(_target)
	{	
		if (__destroyed)
		{
			__scurve_error("Cannot change the target of a destroyed SCurve.");
			return self;
		}

		if (time_source_exists(__step) && time_source_get_state(__step) == time_source_state_active)
		{
			__scurve_error("Cannot change the target of a running SCurve. Stop() it first.");
			return self;
		}

		__target = _target;
		__target_is_struct = is_struct(_target);

		// The captured start values belong to the previous target.
		__needs_init = true;

		return self;
	}

	/// @desc Sets the local time scale for this animation.
	/// @param {Real} scale Speed multiplier (1=normal, 0.5=half, 2=double).
	static TimeScale = function(_scale)
	{
		__time_scale = max(0, _scale);
		return self;
	}

	/// @desc Sets an initial delay for the animation.
	/// @param {Real} seconds Delay time in seconds.
	/// @return {Struct.SCurve} description
	static Delay = function(_seconds)
	{
		__delay = max(0, _seconds);
		return self;
	}
	
	/// @desc Configures a one-shot animation for one or more properties.
	/// @param {Real} _duration Animation duration in seconds.
	/// @param {String} _prop1 Name of the first variable to animate.
	/// @param {Any} _end1 End value of the first property.
	/// @param {String} [_prop2] ...and so on.
	/// @return {Struct.SCurve} this instance
	static To = function(_duration, _prop1, _end1)
	{
		if (__type != SC_TYPE.NONE)
		{
			__scurve_error("An animation is already configured. '.To()' and '.Patrol()' can only be called once.");
			return self;
		}

		if (!is_real(_duration) || _duration < 0)
		{
			__scurve_error($"To() expects a non-negative duration in seconds, got '{_duration}'.");
			return self;
		}

		// One fixed argument (duration) followed by (property, end value) pairs.
		if (argument_count < 3 || (argument_count - 1) mod 2 != 0)
		{
			__scurve_error($"To() expects (property, end value) pairs. Received {argument_count} arguments.");
			return self;
		}

		__type = SC_TYPE.TO;
		__duration = _duration;

		for (var i = 1; i < argument_count; i += 2) { array_push(__properties, new __Property(argument[i], argument[i + 1]) ); }

		return self;
	}

	/// @desc Configures a forward-backward animation for one or more properties.
	/// @param {Real} _duration_go Duration of the forward phase in seconds.
	/// @param {Real} _duration_back Duration of the backward phase in seconds.
	/// @param {Real} _delay Wait time in seconds between forward and backward.
	/// @param {String} _prop1 Name of the first variable to animate.
	/// @param {Any} _end1 End value of the first property in the forward phase.
	/// @param {String} [_prop2] ...and so on for additional properties.
	/// @return {Struct.SCurve} this instance
	static Patrol = function(_duration_go, _duration_back, _delay, _prop1, _end1)
	{
		if (__type != SC_TYPE.NONE)
		{
			__scurve_error("An animation is already configured. '.To()' and '.Patrol()' can only be called once.");
			return self;
		}

		if (!is_real(_duration_go) || _duration_go < 0 || !is_real(_duration_back) || _duration_back < 0)
		{
			__scurve_error("Patrol() expects non-negative phase durations in seconds.");
			return self;
		}

		if (!is_real(_delay) || _delay < 0)
		{
			__scurve_error($"Patrol() expects a non-negative wait delay in seconds, got '{_delay}'.");
			return self;
		}

		// Three fixed arguments (go duration, back duration, delay) followed by (property, end value) pairs.
		if (argument_count < 5 || (argument_count - 3) mod 2 != 0)
		{
			__scurve_error($"Patrol() expects (property, end value) pairs. Received {argument_count} arguments.");
			return self;
		}

		__type = SC_TYPE.PATROL;
		__duration = _duration_go;
		__duration_back = _duration_back;
		__delay_between = _delay;

		for (var i = 3; i < argument_count; i += 2) { array_push(__properties, new __Property(argument[i], argument[i + 1]) ); }

		return self;
	}

	/// @desc Reverses the current direction of a '.To()' or '.Patrol()' animation, whether running or stopped.
	/// @param {Bool} [is_reversed=true] Whether the animation should play in reverse.
	/// @return {Struct.SCurve} description    
	static Reverse = function(_is_reversed = true)
	{
		// If the time source is invalid, there's nothing to reverse.
		if (!time_source_exists(__step) ) 
		{
			__scurve_alert("Cannot reverse SCurve because the time source is invalid. The animation may have been destroyed.");
			return self;
		}
		
		// If the animation type is not defined, there's nothing to reverse.
		if (__type == SC_TYPE.NONE) 
		{
			__scurve_alert("Cannot reverse SCurve because the animation type is not defined. Use '.To()' or '.Patrol()' to define an animation first.");
			return self;
		}

		// Already in the requested state, no need to change.
		if (__is_reversed == _is_reversed)
		{
			__scurve_alert($"SCurve is already in the requested reversed state ({_is_reversed}). No action taken.");
			return self;
		}

		var _time_state = time_source_get_state(__step);
		var _is_active = (_time_state == time_source_state_active || _time_state == time_source_state_paused);

		// Set flag.
		__is_reversed = _is_reversed;

		// If the animation is not active, just set the reversed flag and prepare the phase for the next Play().
		if (!_is_active) { __PreparePhase(); return self; }
		
		switch (__type)
		{
			case SC_TYPE.TO:
				var _duration_ratio = __ComputeToPhaseRatio(__is_reversed);
				__SetToPhase(__is_reversed, true, _duration_ratio);
			break;

			case SC_TYPE.PATROL:
				if (__patrol_state != SC_PATROL_MODE.WAIT)
				{
					var _target_state = __is_reversed ? SC_PATROL_MODE.BACK : SC_PATROL_MODE.GO;
					var _duration_ratio = __ComputePatrolPhaseRatio(_target_state);

					if (_duration_ratio <= 0)
					{
						_target_state = (_target_state == SC_PATROL_MODE.GO) ? SC_PATROL_MODE.BACK : SC_PATROL_MODE.GO;
						_duration_ratio = __ComputePatrolPhaseRatio(_target_state);
					}

					__SetPatrolPhase(_target_state, true, _duration_ratio);
				}
			break;
		}
		
		return self;
	}

	/// @desc Defines how many cycles the animation plays.
	/// @param {Real} [_count=-1] Total cycles to play. 1 = play once, -1 = infinite.
	/// @return {Struct.SCurve} this instance
	static Repeat = function(_count = -1)
	{
		if (!is_real(_count) || _count == 0 || _count < -1)
		{
			__scurve_error($"Repeat() expects a positive cycle count or -1 for infinite, got '{_count}'.");
			return self;
		}

		__repeats = _count;
		return self;
	}
	
	/// @desc Launches one or more SCurves on finish or on a specific repeat.
	///       Accepts any number of (tween, repeat index) arguments; the index defaults to SC_LAUNCH_ON_FINISH.
	/// @param {Struct.SCurve} ... Pairs of SCurve instances and repeat indexes.
	/// @return {Struct.SCurve} this instance
	static Launch = function(...)
	{
		var i = 0;
		while (i < argument_count)
		{
			var _instance = argument[i];

			if (!is_scurve(_instance) )
			{
				__scurve_error($"Launch() argument {i} is not a valid SCurve instance.");
				i++;
				continue;
			}

			// The repeat index is optional: default to launch on finish.
			var _on_repeat = SC_LAUNCH_ON_FINISH;
			if (i + 1 < argument_count && is_real(argument[i + 1]) )
			{
				_on_repeat = argument[i + 1];
				i++;
			}

			array_push(__launch_data, { target: _instance, on_repeat: _on_repeat });
			i++;
		}
		
		return self;
	}

	/// @desc Marks animation for automatic destruction on finish.
	/// @param {Bool} [destroy=true] Whether it should auto-destroy.
	static DestroyOnFinish = function(_destroy = true)
	{
		__destroy_on_finish = _destroy;
		return self;
	}

	/// @desc Assigns one or more tags for group control.
	/// @param {String} tag1 The first tag.
	/// @param {String} [tag2] ...and so on.
	static Tag = function()
	{
		var i = 0; repeat(argument_count)
		{
			var _tag = argument[i++];

			if (!is_string(_tag) || string_length(_tag) == 0)
			{
				__scurve_error("Tag() expects non-empty strings.");
				continue;
			}

			// Ignore duplicates so tag-based control stays predictable.
			if (HasTag(_tag) ) continue;

			array_push(__tags, _tag);
		}

		return self;
	}
	
	/// @desc Defines a callback to run when the animation finishes.
	/// @param {Method} callback The callback function.
	/// @return {Struct.SCurve} description
	static OnFinish = function(_callback)
	{
		__callback_finish = _callback;
		return self;
	}
	
	/// @desc Defines a callback to run when Patrol switches to the backward phase.
	/// @param {Method} callback The callback function.
	/// @return {Struct.SCurve} description
	static OnBack = function(_callback)
	{
		__callback_back = _callback;
		return self;
	}	
	
	/// @desc Defines a callback to run when the Patrol enters the wait phase.
	/// @param {Method} callback The callback function.
	/// @return {Struct.SCurve} description
	static OnWait = function(_callback)
	{
		__callback_wait = _callback;
		return self;
	}

	/// @desc Callback executed on every completed repeat.
	/// @return {Struct.SCurve} description
	static OnRepeat = function(_callback)
	{
		__callback_repeat = _callback;
		return self;
	}

	/// @desc Callback executed when the initial delay ends.
	/// @return {Struct.SCurve} description
	static OnDelay = function(_callback)
	{
		__callback_delay = _callback;
		return self;
	}

	/// @desc Callback executed right after the animation starts.
	/// @param {Method} _callback The callback function.
	/// @return {Struct.SCurve} this instance
	static OnStart = function(_callback)
	{
		__callback_start = _callback;
		return self;
	}

	/// @desc Callback executed every frame after the values are applied.
	/// @param {Method} _callback The callback function, receives the phase progress (0-1).
	/// @return {Struct.SCurve} this instance
	static OnUpdate = function(_callback)
	{
		__callback_update = _callback;
		return self;
	}

	#region STATE QUERIES
	
	/// @desc Returns true if the animation is active and not paused.
	static IsPlaying = function()
	{
		if (!time_source_exists(__step) ) return false;
		return time_source_get_state(__step) == time_source_state_active;
	}
	
	/// @desc Returns true if the animation is paused.
	static IsPaused = function()
	{
		if (!time_source_exists(__step) ) return false;
		return time_source_get_state(__step) == time_source_state_paused;
	}
	
	/// @desc Returns true if the animation has finished or has been stopped.
	static IsFinished = function()
	{
		if (!time_source_exists(__step) ) return true;
		return (time_source_get_state(__step) == time_source_state_stopped);
	}
	
	/// @desc Returns true while the animation is usable (not destroyed and still holding a time source).
	static IsValid = function()
	{
		return !__destroyed && time_source_exists(__step);
	}

	/// @desc Returns true if the animation is in its initial delay phase.
	static IsDelaying = function()
	{
		return __is_delaying;
	}

	/// @desc Returns true if the animation is configured to play in reverse.
	static IsReversed = function()
	{
		return __is_reversed;
	}
	
	#endregion

	#region GETTERS

	/// @desc Returns the animation type as an SC_TYPE value (SC_TYPE.NONE when not configured).
	static GetType = function()
	{
		return __type;
	}

	/// @desc If this is a Patrol, returns its current SC_PATROL_MODE; otherwise undefined.
	static GetPatrolState = function()
	{
		return (__type == SC_TYPE.PATROL) ? __patrol_state : undefined;
	}
	
	/// @desc Returns semantic progress for the current animation direction.
	///       To: 0..1 forward, 0..-1 reverse.
	///       Patrol: 0..1 forward, 1/-1 while waiting, 0..-1 backward.
	static GetProgress = function()
	{
		switch (__type)
		{
			case SC_TYPE.TO: return __is_reversed ? -__progress : __progress;

			case SC_TYPE.PATROL:
				switch (__patrol_state)
				{
					case SC_PATROL_MODE.GO:	return __progress;
					case SC_PATROL_MODE.WAIT:	return __is_reversed ? -1 : 1;
					case SC_PATROL_MODE.BACK:	return -__progress;
				}
			break;
		}

		return __progress;
	}

	/// @desc Returns the raw normalized progress (0-1) of the current phase.
	static GetPhaseProgress = function()
	{
		return __progress;
	}
	
	/// @desc Returns the number of completed repeats.
	static GetRepeatCount = function()
	{
		return __repeat_count;
	}

	/// @desc Checks whether the animation has a specific tag.
	static HasTag = function(_tag)
	{
		return array_get_index(__tags, _tag) > -1;
	}
	
	#endregion
	
	#endregion
}

// Initialize statics.
script_execute(SCMaster);

if (debug_mode)
{
	__scurve_alert($"Debug mode enabled.");

	/// @ignore
	global.__scurve_master__ = static_get(SCMaster);
	
	/// @ignore
	global.__scurve_instances__ = static_get(SCurve);
}
