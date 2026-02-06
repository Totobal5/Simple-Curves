[![Made with GameMaker Studio 2](https://img.shields.io/badge/Made%20with-GameMaker_Studio_2-000000.svg?style=for-the-badge&logo=data%3Aimage%2Fpng%3Bbase64%2CiVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAMAAAAolt3jAAAAZlBMVEX%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2BrG8stAAAAIXRSTlMABg0OFBkfcn1%2Bf4CBgoOFhoeIiouWmNDa5ebp8PX2%2B%2F6o6Vq%2BAAAAY0lEQVR42k2OWQ6AIAwFn%2BIOioobrnD%2FS4o0EeanmQxNAdErRFTWtsFq6%2BiiZozz0CSnTjYBwo0RkF8DWDLf51Ni9K%2FYdq0Fy3KAfzk97M7goK1F%2F4rGH9Kk1OlboQtEDIrmC%2BU3CVxTr%2FRMAAAAAElFTkSuQmCC)](https://www.yoyogames.com/gamemaker)

# Simple-Curves

A lightweight and powerful tween/animation system for GameMaker Studio 2 that uses Animation Curves for precise easing control. Provides a fluent API for creating smooth animations with minimal code.

**Version:** 2.1.0

## Features

- **Fluent API** - Chain methods for intuitive animation setup
- **11 Easing Types** - LINEAR, EASE, CUBIC, QUART, EXPO, CIRC, BACK, ELASTIC, BOUNCE, FAST_SLOW, MID_SLOW
- **Two Animation Types** - `Once` (single direction) and `Patrol` (round-trip)
- **Tag System** - Group and control multiple animations together
- **Time Scale Control** - Global and per-animation timing adjustments
- **Repeat System** - Single, multiple, or infinite repetitions
- **Reverse Playback** - Reverse any animation direction on demand
- **Reusable** - Refresh and replay animations with new values
- **Launch Chain** - Queue animations to play sequentially or on specific repeats
- **Works with Instances & Structs** - Animate any variable on GameMaker instances or custom structs
- **Frame-Independent** - Uses GameMaker's Time Source system for consistent timing

## Installation

1. Clone or download this repository
2. Import the '.yymps' file into your GameMaker Studio 2 project

## Quick Start

### Basic Animation

```gml
// Create a simple animation
new SCurve("Ease")
    .Target(obj_player)
    .Once(1.5, "x", 500)
    .Play();
```

### Animate Multiple Properties

```gml
new SCurve("Cubic")
    .Target(obj_ui)
    .Once(0.8, "x", 300, "y", 200, "alpha", 0.5)
    .Delay(0.3)
    .OnFinish(function() { show_debug_message("Animation done!"); })
    .Play();
```

### Round-Trip Animation (Patrol)

```gml
new SCurve("Ease")
    .Target(button)
    .Patrol(0.5, 0.5, 0.2, "scale_x", 1.1, "scale_y", 1.1)
    .Repeat(-1)  // Infinite repeats
    .Play();
```

## API Reference

### Constructor

#### `SCurve(curve_name, [destroy_on_finish])`
Creates a new animation instance.

**Parameters:**
- `curve_name` *(String)* - Name of the Animation Curve to use (e.g., "Ease", "Cubic", "Bounce")
- `destroy_on_finish` *(Bool, optional)* - Auto-destroy on finish (default: true)

```gml
var anim = new SCurve("Elastic");
```

### Core Methods

#### `Target(target)`
Sets the target instance or struct to animate.

```gml
new SCurve("Linear").Target(my_instance).Play();
```

#### `Once(duration, prop1, end1, [prop2, end2, ...])`
Configures a single-direction animation.

**Parameters:**
- `duration` *(Real)* - Animation duration in seconds
- `prop_name` *(String)* - Variable name to animate
- `end_value` *(Real/String)* - Final value (supports relative syntax: "+100", "-50", "*2", "/2")

```gml
.Once(2.0, "x", 500, "y", "+300")
```

#### `Patrol(duration_go, duration_back, delay, prop1, end1, [prop2, end2, ...])`
Configures a round-trip animation.

**Parameters:**
- `duration_go` *(Real)* - Forward phase duration in seconds
- `duration_back` *(Real)* - Return phase duration in seconds
- `delay` *(Real)* - Wait time between phases in seconds
- `prop_name` *(String)* - Variable name to animate
- `end_value` *(Real/String)* - Value at end of forward phase

```gml
.Patrol(1.0, 1.0, 0.5, "x", 200)
```

#### `ReturningTo(prop1, end_back1, [prop2, end_back2, ...])`
*(Patrol only)* Optionally set different return values for properties.

```gml
.Patrol(1.0, 1.0, 0, "y", 300)
.ReturningTo("y", 100)  // Returns to 100 instead of starting position
```

### Timing Methods

#### `Delay(seconds)`
Sets initial delay before animation starts.

```gml
.Delay(0.5)
```

#### `TimeScale(scale)`
Sets animation speed multiplier (1.0 = normal, 0.5 = half speed, 2.0 = double speed).

```gml
.TimeScale(0.8)
```

#### `Repeat(count)`
Sets number of repetitions (-1 for infinite).

```gml
.Repeat(3)      // Repeat 3 times
.Repeat(-1)     // Infinite loop
```

### Playback Control

#### `Play()`
Starts the animation.

```gml
new SCurve("Ease").Target(obj).Once(1, "x", 100).Play();
```

#### `Pause()`
Pauses the animation.

```gml
anim.Pause();
```

#### `Resume()`
Resumes a paused animation.

```gml
anim.Resume();
```

#### `Stop()`
Stops the animation and resets timing.

```gml
anim.Stop();
```

#### `Refresh()`
Recaptures initial property values from target. Useful for reusable animations.

```gml
anim.Refresh().Play();
```

#### `Destroy()`
Cleans up animation resources.

```gml
anim.Destroy();
```

### Direction Control

#### `Reverse([is_reversed])`
*(Once only)* Reverses animation direction.

```gml
.Once(1.0, "x", 500)
.Reverse(true)   // Animates from 500 back to original value
.Play();
```

### Callbacks

#### `OnFinish(callback)`
Executes when animation completes.

```gml
.OnFinish(function() { show_debug_message("Done!"); })
```

#### `OnRepeat(callback)`
Executes on each repeat completion (receives repeat count as parameter).

```gml
.OnRepeat(function(repeat_num) { 
    show_debug_message("Repeat " + string(repeat_num)); 
})
```

#### `OnDelayFinish(callback)`
Executes when initial delay completes.

```gml
.OnDelayFinish(function() { show_debug_message("Delay over"); })
```

#### `OnContinue(callback)`
*(Patrol only)* Executes when forward phase completes.

```gml
.OnContinue(function() { show_debug_message("Reached target"); })
```

#### `OnWait(callback)`
*(Patrol only)* Executes when wait phase completes.

```gml
.OnWait(function() { show_debug_message("Starting return"); })
```

### Animation Chaining

#### `Launch(scurve_instance, [on_repeat_count])`
Launches another animation at the end or on specific repeat.

```gml
var anim1 = new SCurve("Ease").Target(obj).Once(1, "x", 100);
var anim2 = new SCurve("Ease").Target(obj).Once(1, "y", 200);

anim1.Launch(anim2).Play();  // anim2 plays after anim1
```

#### `DestroyOnFinish([destroy])`
Controls auto-destruction behavior.

```gml
.DestroyOnFinish(false)  // Keep animation instance after finish
```

### Tagging System

#### `Tag(...tags)`
Assigns one or more tags for group control.

```gml
.Tag("ui", "menu")
```

#### `HasTag(tag)`
Checks if animation has a specific tag.

```gml
if (anim.HasTag("ui")) { /* ... */ }
```

### State Queries

#### `IsPlaying()`
Returns true if animation is actively running.

```gml
if (anim.IsPlaying()) { show_debug_message("Running"); }
```

#### `IsPaused()`
Returns true if animation is paused.

```gml
if (anim.IsPaused()) { anim.Resume(); }
```

#### `IsFinished()`
Returns true if animation has stopped or completed.

```gml
if (anim.IsFinished()) { show_debug_message("Complete"); }
```

#### `IsDelaying()`
Returns true if currently in delay phase.

```gml
if (anim.IsDelaying()) { /* ... */ }
```

#### `IsReversed()`
Returns true if animation is configured to play in reverse.

```gml
if (anim.IsReversed()) { /* ... */ }
```

#### `GetType()`
Returns animation type ("once" or "patrol").

```gml
var type = anim.GetType();
```

#### `GetPatrolState()`
*(Patrol only)* Returns current phase ("go", "wait", or "back").

```gml
if (anim.GetPatrolState() == "back") { /* ... */ }
```

#### `GetProgress()`
Returns normalized progress (0-1) of current phase.

```gml
var progress = anim.GetProgress();
```

#### `GetRepeatCount()`
Returns number of completed repeats.

```gml
show_debug_message("Repeats done: " + string(anim.GetRepeatCount()));
```

## SCMaster - Global Animation Control

### Static Methods

#### `PauseAll()`
Pauses all active animations.

```gml
SCMaster.PauseAll();
```

#### `ResumeAll()`
Resumes all paused animations.

```gml
SCMaster.ResumeAll();
```

#### `SetGlobalTimeScale(scale)`
Sets global time scale for all animations.

```gml
SCMaster.SetGlobalTimeScale(0.5);  // Slow-motion effect
```

#### `GetGlobalTimeScale()`
Gets current global time scale.

```gml
var scale = SCMaster.GetGlobalTimeScale();
```

#### `PauseTag(tag)`
Pauses all animations with a specific tag.

```gml
SCMaster.PauseTag("ui");
```

#### `ResumeTag(tag)`
Resumes animations with a specific tag.

```gml
SCMaster.ResumeTag("ui");
```

#### `StopTag(tag)`
Stops all animations with a specific tag.

```gml
SCMaster.StopTag("effects");
```

#### `DestroyTag(tag)`
Destroys all animations with a specific tag.

```gml
SCMaster.DestroyTag("temp");
```

#### `SetTimeScaleByTag(tag, scale)`
Sets time scale for animations with a specific tag.

```gml
SCMaster.SetTimeScaleByTag("ui", 1.5);  // UI animations 50% faster
```

#### `StaggerLaunch(stagger_delay, anim1, ...)`
Launches multiple animations with staggered delays.

```gml
SCMaster.StaggerLaunch(0.1, anim1, anim2, anim3);  // 0.1s between each
```

## Easing Curves

Simple Curves includes 11 easing presets:

| Curve | Description |
|-------|-------------|
| `LINEAR` | No easing, constant speed |
| `EASE` | Smooth ease in/out |
| `CUBIC` | Cubic ease in/out |
| `QUART` | Quartic ease in/out |
| `EXPO` | Exponential ease in/out |
| `CIRC` | Circular ease in/out |
| `BACK` | Back overshoot ease in/out |
| `ELASTIC` | Elastic bounce ease in/out |
| `BOUNCE` | Bouncy ease in/out |
| `FAST_SLOW` | Fast start, slow finish |
| `MID_SLOW` | Slow middle section |

## Advanced Examples

### Animate With Relative Values

```gml
new SCurve("Ease")
    .Target(player)
    .Once(1.0, "x", "+100", "y", "-50")  // +100 pixels right, -50 down
    .Play();
```

### Sequential Animation Chain

```gml
var fade_out = new SCurve("Ease")
    .Target(ui_element)
    .Once(0.5, "alpha", 0);

var move = new SCurve("Cubic")
    .Target(ui_element)
    .Once(1.0, "x", 800);

fade_out.Launch(move).Play();
```

### Infinite Bouncing with Events

```gml
new SCurve("Bounce")
    .Target(obj_ball)
    .Patrol(0.5, 0.5, 0, "y", "-100")
    .Repeat(-1)
    .OnContinue(function() { play_sound(snd_bounce); })
    .Play();
```

### Reusable Animation Template

```gml
function create_pulse_animation(target) {
    return new SCurve("Ease")
        .Target(target)
        .Patrol(0.2, 0.2, 0, "scale_x", 1.2, "scale_y", 1.2)
        .Repeat(1)
        .DestroyOnFinish(false);
}

// Reuse multiple times
var pulse = create_pulse_animation(button1);
pulse.Play();
// Later...
pulse.Refresh().Play();
```

### Group Control with Tags

```gml
// Create multiple UI animations with tags
new SCurve("Ease").Target(btn1).Once(0.5, "alpha", 0).Tag("ui", "menu").Play();
new SCurve("Ease").Target(btn2).Once(0.5, "alpha", 0).Tag("ui", "menu").Play();
new SCurve("Ease").Target(btn3).Once(0.5, "alpha", 0).Tag("ui", "menu").Play();

// Control them all at once
SCMaster.PauseTag("menu");      // Pause all
SCMaster.ResumeTag("menu");     // Resume all
SCMaster.SetTimeScaleByTag("menu", 0.5);  // Slow down menu animations
```

### Slow-Motion Effect

```gml
// Pause game logic but keep animations at slower speed
SCMaster.SetGlobalTimeScale(0.3);

// Later, resume normal speed
SCMaster.SetGlobalTimeScale(1.0);
```

## Performance Considerations

- Simple Curves uses GameMaker's Time Source system for frame-independent timing
- Delta time is clamped to maintain smooth animation during frame drops
- Animations are automatically unregistered from the global manager when destroyed
- Use tags to efficiently manage groups of animations
- The library handles both instances and structs, adapting to the target type

## Testing

Example usage is demonstrated in `o_iamfade` object:
- Creates a reversible animation on struct animation data
- Press spacebar to reverse/toggle animation direction
- Shows how to use callbacks and state queries

## License

See LICENSE file for details.