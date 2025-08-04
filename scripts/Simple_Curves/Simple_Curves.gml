// Feather ignore all

/// @ignore
#macro SC_VERSION		"1.0"

/// @ignore
#macro SC_MIN_DELTA_FPS	15

#macro SC_TYPE_ONCE		"once"
#macro SC_TYPE_BOUNCE	"bounce"
#macro SC_TYPE_PATROL	"patrol"
#macro SC_TYPE_LOOP		"loop"

/// @desc Gestor singleton para controlar todas las animaciones SCurve.
function SCMaster()
{
	static list = [];
	static time_scale = 1.0;
	
	/// @desc Registra una animación en la lista global.
	static Register = function(_scurve_instance)
	{
		array_push(list, _scurve_instance);
	}
	
	/// @desc Elimina una animación de la lista global.
	static Unregister = function(_scurve_instance)
	{
		var _index = array_get_index(list, _scurve_instance);
		if (_index > -1)
		{
			array_delete(list, _index, 1);
		}
	}
	
	/// @desc Pausa todas las animaciones activas.
	static PauseAll = function()
	{
		for (var i = 0; i < array_length(list); i++)
		{
			list[i].Pause();
		}
	}
	
	/// @desc Reanuda todas las animaciones pausadas.
	static ResumeAll = function()
	{
		for (var i = 0; i < array_length(list); i++)
		{
			list[i].Resume();
		}
	}
	
	/// @desc Establece una escala de tiempo global para todas las animaciones.
	static SetGlobalTimeScale = function(_scale)
	{
		time_scale = max(0, _scale);
	}
	
	/// @desc Obtiene la escala de tiempo global actual.
	static GetGlobalTimeScale = function()
	{
		return time_scale;
	}

	/// @desc Pausa todas las animaciones que contengan la etiqueta especificada.
	static PauseTag = function(_tag)
	{
		for (var i = 0; i < array_length(list); i++)
		{
			if (list[i].HasTag(_tag)) list[i].Pause();
		}
	}
	
	/// @desc Reanuda todas las animaciones que contengan la etiqueta especificada.
	static ResumeTag = function(_tag)
	{
		for (var i = 0; i < array_length(list); i++)
		{
			if (list[i].HasTag(_tag)) list[i].Resume();
		}
	}
	
	/// @desc Detiene todas las animaciones que contengan la etiqueta especificada.
	static StopTag = function(_tag)
	{
		// Se itera hacia atrás porque Stop() modifica el array 'list'.
		for (var i = array_length(list) - 1; i >= 0; i--)
		{
			if (list[i].HasTag(_tag)) list[i].Stop();
		}
	}
	
	/// @desc Destruye todas las animaciones que contengan la etiqueta especificada.
	static DestroyTag = function(_tag)
	{
		// Se itera hacia atrás porque Destroy() modifica el array 'list'.
		for (var i = array_length(list) - 1; i >= 0; i--)
		{
			if (list[i].HasTag(_tag)) list[i].Destroy();
		}
	}
	
	/// @desc Establece la escala de tiempo para todas las animaciones con una etiqueta.
	static SetTimeScaleByTag = function(_tag, _scale)
	{
		for (var i = 0; i < array_length(list); i++)
		{
			if (list[i].HasTag(_tag)) list[i].TimeScale(_scale);
		}
	}

	/// @desc Lanza una serie de animaciones con un retraso escalonado entre cada una.
	/// @param {Real} stagger_delay El retraso en segundos entre cada animación.
	/// @param {Struct.SCurve} anim1... La primera animación a lanzar.
	static StaggerLaunch = function(_stagger_delay, _anim1)
	{
		for (var i = 1; i < argument_count; i++)
		{
			var _anim = argument[i];
			var _cumulative_delay = _stagger_delay * (i - 1);
			
			_anim.Delay(_cumulative_delay);
			_anim.Play();
		}
	}
}

/// @desc Crea y gestiona una animación basada en una curva.
/// @param {String} curve El nombre de la Animation Curve a utilizar.
/// @param {Bool} [destroy_on_finish=true] (Opcional) Si la animación debe destruirse automáticamente al terminar.
function SCurve(_curve, _destroy_on_finish=true) constructor
{
	// --- Variables estáticas compartidas por todas las animaciones ---
	static __fps =				game_get_speed(gamespeed_fps);
	static __delta_previous =	delta_time / 1000000;
	static __delta =			delta_time / 1000000;
	
	// --- Variables para la protección contra picos de lag ---
	// Límite máximo para delta time (equivale a 15 FPS). Si el juego baja de esto, se activa la protección.
	static __delta_max = 1 / SC_MIN_DELTA_FPS;
	// Bandera para saber si estamos en un estado de "lag".
	static __delta_restored = false;

	// Registrar esta instancia en el gestor global
	SCMaster.Register(self);
	
	// Por default el target será quien lo cree.
	Target(other);
	
	// Actualizar Delta al ser creado.
	__Delta();
	
	// --- Propiedades de la instancia de la curva ---
	__type =		"";
	__time =		0;
	__delay =		0;
	__duration =	1;
	__pause =		false;
	__value =		0;
	// Escala de tiempo para esta animación.
	__time_scale =	1.0;
	// Bandera para el estado de retraso inicial
	__is_delaying = false;
	// Bandera para el modo inverso
	__is_reversed = false;
	// Bandera para la autodestrucción (Default: True)
	__destroy_on_finish = _destroy_on_finish;
	// Array para almacenar etiquetas
	__tags = []; 
	
	// La instancia o struct a animar.
	__target =			noone;
	// Array de structs: { name: "x", start: 0, end: 500 }
	__properties =		[];

	__duration_back = 0;
	__end_value_back = 0;
	__delay_between = 0;
	// Estados: "go", "wait", "back"
	__patrol_state = "go";
	
	// 0 = no repetir, -1 = infinito
	__repeats = 0;
	__repeat_count = 0;
	__launch_data = [];


	// Canal que se usará.
	__channel_index =	animcurve_get_channel_index(Simple_Curves_Animation, _curve);
	__channel_struct =	animcurve_get_channel(Simple_Curves_Animation, __channel_index);
	__channel_struct_back = undefined;
	
	// Definir callbacks.
	__callback_finish = undefined;			// Al terminar.
	__callback_wait = undefined;			// Al terminar la pausa en .Patrol().
	__callback_continue = undefined;		// Al continuar.
	__callback_repeat = undefined;			// Por cada cuenta.
	__callback_delay_finish = undefined;	// Al final del delay
	
	__step = time_source_create(time_source_game, 1, time_source_units_frames, method(self, __Update), [], -1, time_source_expire_after);
	
	#region Privates
	/// @ignore
	/// @desc El bucle principal de la animación, se ejecuta en cada fotograma.
	static __Update = function()
	{
		// Actualizar delta.
		__Delta();
		
		if (__pause) return;
		
		// Aplicar escala de tiempo global y local.
		var _scaled_delta = __delta * __time_scale * SCMaster.GetGlobalTimeScale();
		var _animation_finished = false;

		if (__is_delaying)
		{
			__delay -= _scaled_delta;
			if (__delay <= 0)
			{
				__is_delaying = false;
				// Añadir el tiempo sobrante del delay a la animación para no perder precisión
				__time += abs(__delay); 
				if (is_method(__callback_delay_finish) ) __callback_delay_finish();
			}
			
			// No procesar nada más hasta que el delay termine.
			return; 
		}
		
		switch (__type)
		{
			// --- Lógica para animación de un solo ciclo ---
			case SC_TYPE_ONCE:
				__time += _scaled_delta;
				// Calcular el progreso basado en si está en reversa
				__value = __is_reversed ? 1.0 - (__time / __duration) : (__time / __duration);
				
				// Condición de finalización basada en el tiempo
				if (__time >= __duration) 
				{
					// Asegurar que el valor final sea exacto
					__value = __is_reversed ? 0 : 1; 
					_animation_finished = true;
				}
				
				__ApplyValue(__value, __channel_struct);
			break;
			
			// --- Lógica para el modo Patrol ---
			case SC_TYPE_PATROL:
				switch (__patrol_state)
				{
					case "go":
						__time += _scaled_delta;
						__value = __time / __duration;
						if (__value >= 1) {
							__value = 1;
							__patrol_state = "wait";
							__time = 0;
							if (is_method(__callback_continue)) __callback_continue();
						}
						__ApplyValue(__value, __channel_struct);
					break;
					
					case "wait":
						__time += _scaled_delta;
						if (__time >= __delay_between) {
							__patrol_state = "back";
							__time = 0;
							if (is_method(__callback_wait)) __callback_wait();
						}
					break;
					
					case "back":
						__time += _scaled_delta;
						__value = __time / __duration_back;
						if (__value >= 1) {
							__value = 1;
							_animation_finished = true;
						}
						__ApplyValue(__value, __channel_struct_back ?? __channel_struct);
					break;
				}
			break;
		}
		
		// --- Lógica de repetición al final del ciclo ---
		if (_animation_finished)
		{
			if (__repeats != 0)
			{
				__repeat_count++;
				if (is_method(__callback_repeat) ) __callback_repeat(__repeat_count);
						
				for (var i = 0; i < array_length(__launch_data); i++) 
				{
					var _launch = __launch_data[i];
					if (is_struct(_launch.target) && _launch.on_repeat == __repeat_count)
					{
						_launch.target.Play();
					}
				}
				
				if (__repeat_count >= __repeats && __repeats != -1)
				{
					if (is_method(__callback_finish)) __callback_finish();
					for (var i = 0; i < array_length(__launch_data); i++) 
					{
						var _launch = __launch_data[i];
						if (is_struct(_launch.target) && _launch.on_repeat == 0) 
						{
							_launch.target.Play();
						}
					}
					
					// Decidir si destruir o detener
					if (__destroy_on_finish) { Destroy(); } else { Stop(); }
				}
				else
				{
					__ResetAnimation();
				}
			}
			else
			{
				if (is_method(__callback_finish)) __callback_finish();
				for (var i = 0; i < array_length(__launch_data); i++) 
				{
					var _launch = __launch_data[i];
					if (is_struct(_launch.target) ) 
					{
						_launch.target.Play();
					}
				}
				
				// Decidir si destruir o detener
				if (__destroy_on_finish) { Destroy(); } else { Stop(); }
			}
		}
	}
	
	/// @ignore
	/// @desc Calcula el delta time y lo protege contra picos de lag.
	static __Delta = function()
	{
		// --- Manejo y cálculo del Delta Time ---
		__delta_previous = __delta; // Guardar el delta del fotograma anterior.
		
		var _current_delta = delta_time / 1000000; // Calcular el delta actual en segundos.
		
		// --- Lógica de protección contra picos de lag ---
		if (_current_delta > __delta_max)
		{
			// Si el delta time es demasiado grande (caída de FPS)...
			// Usamos un valor seguro para evitar un salto brusco en la animación.
			__delta = __delta_restored ? __delta_max : __delta_previous;
			// Marcamos que el sistema está en modo "restauración".
			__delta_restored = true;
		}
		else
		{
			// Si el rendimiento es normal, usamos el delta actual.
			__delta = _current_delta;
			// Desmarcamos el modo "restauración".
			__delta_restored = false;
		}
	}

	/// @ignore
	/// @desc Aplica el valor calculado a las propiedades del target.
	static __ApplyValue = function(_value, _channel)
	{
		var _eased_value = animcurve_channel_evaluate(_channel, _value);
		
		for (var i = 0; i < array_length(__properties); i++)
		{
			var _prop =	__properties[i];
			var _start = _prop.start;
			var _end = _prop.finish;

			if (__type == SC_TYPE_PATROL && __patrol_state == "back")
			{
				_start = _prop.finish;
				_end = _prop.finish_back ?? _prop.start;
			}
			
			var _final_value = lerp(_start, _end, _eased_value);
			
			// --- Comprobación para Structs e Instancias ---
			if (is_struct(__target))
			{
				variable_struct_set(__target, _prop.name, _final_value);
			}
			else if (instance_exists(__target))
			{
				variable_instance_set(__target, _prop.name, _final_value);
			}
		}
	}

	/// @ignore
	/// @desc Reinicia el estado de la animación para una nueva repetición.
	static __ResetAnimation = function()
	{
		__time = 0;
		__value = 0;
		if (__type == SC_TYPE_PATROL)
		{
			__patrol_state = "go";
		}

		// Re-inicializar las propiedades para la siguiente repetición
		__InitializeProperties();		
	}
	
	/// @ignore
	/// @desc Constructor interno para almacenar los datos de cada propiedad a animar.
	static __Property = function(_name, _finish) constructor
	{
		name = _name;
		start = 0;
		finish = _finish;
		finish_back = undefined;
	}
	
	/// @ignore
	/// @desc Calcula un valor final a partir de un string relativo (ej: "+=100").
	static __CalculateRelativeValue = function(_base_value, _relative_string)
	{
	    var _operator = string_char_at(_relative_string, 1);
	    var _value_str = string_delete(_relative_string, 1, 1);
	    var _value = real(_value_str);

	    // Comprueba si la conversión falló (real() devuelve 0 para strings no numéricos)
	    if (_value == 0 && _value_str != "0" && _value_str != ".0" && _value_str != "-0")
	    {
	        show_debug_message($"SCurve Error: Valor numerico invalido '{_value_str}' en string relativo '{_relative_string}'.");
	        return _base_value; // En caso de error, devuelve el valor original
	    }
    
	    switch (_operator)
	    {
	        case "+": return _base_value + _value;
	        case "-": return _base_value - _value;
	        case "*": return _base_value * _value;
	        case "/": 
	            if (_value == 0) {
	                show_debug_message($"SCurve Warning: Division por sero en string relativo '{_relative_string}'.");
	                return _base_value;
	            }
	            return _base_value / _value;
	    }
    
		// Fallback
	    return _base_value;
	}

	/// @ignore
	/// @desc "Compila" las propiedades, obteniendo sus valores iniciales y calculando los relativos.
	static __InitializeProperties = function()
	{
		var _get_var = is_struct(__target) ? variable_struct_get : variable_instance_get;
		
		if (is_struct(__target) || instance_exists(__target))
		{
			for (var i = 0; i < array_length(__properties); i++)
			{
				var _prop = __properties[i];
				_prop.start = _get_var(__target, _prop.name);
				
				// Copiamos el valor final original por si es relativo y necesitamos recalcularlo
				var _finish_val = _prop.finish;
				if (is_string(_finish_val) && string_length(_finish_val) > 0)
				{
					var _operator = string_char_at(_finish_val, 1);
					if (string_pos(_operator, "+-*/") > 0)
					{
						_prop.finish = __CalculateRelativeValue(_prop.start, _finish_val);
					}
					else
					{
						_prop.finish = real(_finish_val);
					}
				}
				
				var _finish_back_val = _prop.finish_back;
				if (__type == SC_TYPE_PATROL && is_string(_finish_back_val) && string_length(_finish_back_val) > 0)
				{
					var _operator = string_char_at(_finish_back_val, 1);
					if (string_pos(_operator, "+-*/") > 0)
					{
						var _base_for_return = _prop.finish;
						_prop.finish_back = __CalculateRelativeValue(_base_for_return, _finish_back_val);
					}
					else
					{
						_prop.finish_back = real(_finish_back_val);
					}
				}
			}
		}
	}
	
	#endregion
	
	#region API
	/// @desc Inicia la animación.
	static Play = function()
	{
		var _time_state = time_source_get_state(__step);
		if (_time_state == time_source_state_initial || _time_state == time_source_state_stopped)
		{
			// Iniciar SCurve.
			// Solo inicializa las propiedades la primera vez
			if (_time_state == time_source_state_initial)
			{
				__InitializeProperties();
			}
			
			// Reiniciar el tiempo y el delay para permitir la reproducción inversa o reinicio
			__time = 0;
			if (__delay > 0) {__is_delaying = true; }
			
			time_source_start(__step);
			__pause = false;
		}
		
		show_debug_message(_time_state);
		
		return self;		
	}
	
	/// @desc Detiene la animación.
	static Stop = function()
	{
		time_source_stop(__step);
		return self;
	}
	
	/// @desc Pausa la animación.
	static Pause = function()
	{
		__pause = true;
		return self;
	}
	
	/// @desc Reanuda la animación.
	static Resume = function()
	{
		__pause = false;
		return self;
	}

	// Método para destruir la animación y liberar recursos
	static Destroy = function()
	{
		if (time_source_exists(__step) )
		{
			time_source_destroy(__step);
			// Marcar como inválido
			__step = -1;
		}
		
		SCMaster.Unregister(self);
	}
	
	/// @desc Define el objetivo y la propiedad a animar.
	/// @param {Id.Instance | Struct} target La instancia o struct a animar.
	static Target = function(_target)
	{	
		__target = _target;
		return self;
	}

	/// @desc Define la escala de tiempo para esta animación.
	/// @param {Real} scale Multiplicador de velocidad (1=normal, 0.5=mitad, 2=doble).
	static TimeScale = function(_scale)
	{
		__time_scale = max(0, _scale); // Prevenir escalas de tiempo negativas
		return self;
	}

	/// @desc Establece un retraso inicial para la animación.
	/// @param {Real} seconds Tiempo de retraso en segundos.
	static Delay = function(_seconds)
	{
		__delay = max(0, _seconds);
		return self;
	}
	
	/// @desc Configura una animación de un solo ciclo para una o más propiedades.
	/// @param {Real} duration La duración de la animación en segundos.
	/// @param {String} prop1 El nombre de la primera variable a animar.
	/// @param {Any} end1 El valor final de la primera propiedad.
	/// @param {String} [prop2] ... y así sucesivamente.
	static Once = function(_duration, _prop1, _end1)
	{
		if (__type != "") 
		{
			show_debug_message("SCurve Error: El tipo de animación (Once/Patrol) ya ha sido definido.");
			return self;
		}
		
		__type = SC_TYPE_ONCE;
		__duration = _duration;
		
		for (var i = 1; i < argument_count; i += 2)
		{
			array_push(__properties, new __Property(argument[i], argument[i+1]) );
		}
		
		return self;
	}

	/// @desc Configura una animación de ida y vuelta para una o más propiedades.
	/// @param {Real}   duration_go      Duración de la fase de "ida" en segundos.
	/// @param {Real}   duration_back    Duración de la fase de "vuelta" en segundos.
	/// @param {Real}   delay            Espera en segundos entre la ida y la vuelta.
	/// @param {String} prop1            El nombre de la primera variable a animar.
	/// @param {Any}    end1             El valor final de la primera propiedad en la fase de "ida".
	/// @param {String} [prop2]          ... y así sucesivamente para más propiedades.
	static Patrol = function(_duration_go, _duration_back, _delay, _prop1, _end1)
	{
		if (__type != "") 
		{
			show_debug_message("SCurve Error: El tipo de animación (Once/Patrol) ya ha sido definido.");
			return self;
		}
		
		__type = SC_TYPE_PATROL;
		__duration = _duration_go;
		__duration_back = _duration_back;
		__delay_between = _delay;
		
		for (var i = 3; i < argument_count; i += 2)
		{
			array_push(__properties, new __Property(argument[i], argument[i+1]) );
		}
		return self;
	}

	/// @desc Invierte la dirección de una animación de tipo Once.
	/// @param {Bool} [is_reversed=true] Si la animación debe reproducirse en reversa.
	static Reverse = function(_is_reversed = true)
	{
		if (__type != "" && __type != SC_TYPE_ONCE)
		{
			show_debug_message("SCurve Warning: .Reverse() solo tiene efecto en animaciones de tipo Once.");
			return self;
		}
		
		var _time_state = time_source_get_state(__step);
		if (_time_state == time_source_state_stopped)
		{
			__is_reversed = _is_reversed;
		}
		
		return self;
	}

	/// @desc (Opcional) Define los valores de retorno para un Patrol. Debe ser llamado DESPUÉS de .Patrol().
	/// @param {String} prop1 El nombre de la primera variable a modificar en la vuelta.
	/// @param {Any} end_back1 El valor final de la primera propiedad en la vuelta. Puede ser relativo.
	/// @param {String} [prop2] ... y así sucesivamente.
	static ReturningTo = function(_prop1, _end_back1)
	{
	    if (__type != SC_TYPE_PATROL)
	    {
	        show_debug_message("SCurve Warning: .ReturningTo() solo tiene efecto en animaciones de tipo Patrol.");
	        return self;
	    }
	
	    for (var i = 0; i < argument_count; i += 2)
	    {
	        var _prop_name = argument[i];
	        var _end_back_value = argument[i+1];
	        var _found = false;
	
	        // Busca la propiedad correspondiente en el array __properties
	        for (var j = 0; j < array_length(__properties); j++)
	        {
	            if (__properties[j].name == _prop_name)
	            {
	                __properties[j].finish_back = _end_back_value;
	                _found = true;
	                break;
	            }
	        }
	
	        if (!_found)
	        {
	            show_debug_message($"SCurve Warning: Propiedad '{_prop_name}' no encontrada para definir valor de retorno en .ReturningTo().");
	        }
	    }
	    return self;
	}
	
	/// @desc Define cuantas veces se repetirá la animación.
	/// @param {Real} count Número de repeticiones. -1 para infinito.
	static Repeat = function(_count)
	{
	    // Si _count es <= 0, se asume repetición infinita (-1)
	    __repeats = (_count <= 0) ? -1 : _count;
	    return self;
	}
	
	/// @desc Lanza otro SCurve al terminar o en una repetición específica.
	/// @param {Struct.SCurve} scurve_instance La instancia de SCurve a lanzar.
	/// @param {Real} [on_repeat_count] (Opcional) El número de repetición en el que se lanzará. Si no se especifica, se lanza al final.
	static Launch = function(_scurve_instance, _on_repeat_count = 0)
	{
		for (var i = 0; i < argument_count; i += 2)
		{
		    array_push(__launch_data, 
			{
		        target:		argument[i],
		        on_repeat:	argument[i+1]
		    });
		}		
		
	    return self;
	}

	/// @desc Marca la animación para que se destruya automáticamente al finalizar.
	/// @param {Bool} [destroy=true] Si debe autodestruirse.
	static DestroyOnFinish = function(_destroy = true)
	{
		__destroy_on_finish = _destroy;
		return self;
	}

	/// @desc Asigna una o más etiquetas a la animación para su control en grupo.
	static Tag = function()
	{
		for (var i = 0; i < argument_count; i++)
		{
			array_push(__tags, argument[i]);
		}
		return self;
	}
	
	/// @desc Define una función a llamar cuando la animación termina.
	/// @param {Method} callback La función a ejecutar.
	static OnFinish = function(_callback)
	{
		__callback_finish = _callback;
		return self;
	}
	
	/// @desc Define una función a llamar cuando la animación termina.
	/// @param {Method} callback La función a ejecutar.
	static OnContinue = function(_callback)
	{
		__callback_continue = _callback;
		return self;
	}	
	
	/// @desc Define una función a llamar cuando la animación termina.
	/// @param {Method} callback La función a ejecutar.
	static OnWait = function(_callback)
	{
		__callback_wait = _callback;
		return self;
	}

	/// @desc Callback que se ejecuta en cada repetición completada.
	static OnRepeat = function(_callback)
	{
	    __callback_repeat = _callback;
	    return self;
	}

	/// @desc Callback que se ejecuta cuando el delay inicial termina.
	static OnDelayFinish = function(_callback)
	{
	    __callback_delay_finish = _callback;
	    return self;
	}

		#region State Queries.
	
	/// @desc Devuelve true si la animación está activa y no pausada.
	static IsPlaying = function()
	{
		return time_source_get_state(__step) == time_source_state_active && !__pause;
	}
	
	/// @desc Devuelve true si la animación está pausada.
	static IsPaused = function()
	{
		return __pause;
	}
	
	/// @desc Devuelve true si la animación ha terminado o ha sido detenida.
	static IsFinished = function()
	{
		return time_source_get_state(__step) == time_source_state_stopped;
	}
	
	/// @desc Devuelve true si la animación está en su fase de retraso inicial.
	static IsDelaying = function()
	{
		return __is_delaying;
	}

	/// @desc Devuelve true si la animación está configurada para reproducirse en reversa.
	static IsReversed = function()
	{
		return __is_reversed;
	}
	
	/// @desc Devuelve el tipo de animación ("once" o "patrol").
	static GetType = function()
	{
		return __type;
	}
	
	/// @desc Si es un Patrol, devuelve su estado actual ("go", "wait", "back").
	static GetPatrolState = function()
	{
		return (__type == SC_TYPE_PATROL) ? __patrol_state : undefined;
	}
	
	/// @desc Devuelve el progreso normalizado (0-1) del segmento actual.
	static GetProgress = function()
	{
		return __value;
	}
	
	/// @desc Devuelve el número de repeticiones completadas.
	static GetRepeatCount = function()
	{
		return __repeat_count;
	}

	/// @desc Comprueba si la animación tiene una etiqueta específica.
	static HasTag = function(_tag)
	{
		return array_get_index(__tags, _tag) > -1;
	}
	
		#endregion
	
	#endregion
}


// Iniciar statics
script_execute(SCMaster);