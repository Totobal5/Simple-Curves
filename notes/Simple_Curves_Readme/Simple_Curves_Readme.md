# Simple-Curves

A lightweight tween library for GameMaker built on Animation Curves.

## Features

- Lightweight tween core (`SCurve`) with fluent chaining
- Global manager (`SCMaster`) for batch control by tag or globally
- Two tween modes:
  - `To` (single direction)
  - `Patrol` (go -> wait -> back)
- Reverse support while running or stopped
- Repeat support (`count` or infinite)
- Launch chained tweens on finish or specific repeat
- Callback hooks for finish, repeat, delay, wait, and back
- Works with both instances and structs
- Delta protection for lag spikes

## Installation

1. Import the `.yymps` package into your GameMaker project.

## Quick Start

### Basic Tween (`To`)

```gml
// In Create event
anim = new SCurve(SCURVE.EASE)
  .Target(self)
  .To(0.5, "x", 320)
  .Play();
```

### Patrol Tween (`Patrol`)

```gml
// Go 1s -> wait 0.2s -> back 0.6s
patrol = new SCurve(SCURVE.CUBIC, false)
  .Target(self)
  .Patrol(1.0, 0.6, 0.2, "image_xscale", 2)
  .Repeat()
  .Play();
```

### Reverse While Active

```gml
anim = new SCurve(SCURVE.QUART)
  .Target(self)
  .To(1.0, "x", 500)
  .Play();

// Later
anim.Reverse(true);
```

## Constructor

### `SCurve(curve, [destroy_on_finish=true])`

- `curve`: one of the `SCURVE` enum values
- `destroy_on_finish`: if `true`, auto-destroys at finish

```gml
var anim = new SCurve(SCURVE.ELASTIC);
```

## API Reference

### SCurve (Tween Instance)

| Method | Description |
|--------|-------------|
| `Target(target)` | Set instance or struct to animate |
| `To(duration, prop1, end1, ...)` | Configure one-way tween |
| `Patrol(duration_go, duration_back, delay, prop1, end1, ...)` | Configure go/wait/back tween |
| `Delay(seconds)` | Initial delay before movement starts (applied at the start of every cycle) |
| `TimeScale(scale)` | Per-tween speed multiplier (`<= 0` freezes the tween) |
| `Repeat(count=-1)` | Total cycles (`1` = play once, `-1` = infinite) |
| `Launch(tween, on_repeat, ...)` | Launch one or more tweens at finish or on a given cycle |
| `DestroyOnFinish(destroy=true)` | Toggle auto-destroy on finish |
| `Tag(tag1, tag2, ...)` | Add tags for group management |
| `Play()` | Start tween |
| `Pause()` | Pause tween |
| `Resume()` | Resume tween |
| `Stop()` | Stop tween |
| `Refresh()` | Re-capture starts and rebuild phase data |
| `Destroy()` | Destroy tween and release all its resources |
| `Reverse(is_reversed=true)` | Reverse direction/state intent |
| `OnFinish(callback)` | Callback when tween fully finishes |
| `OnRepeat(callback)` | Callback after each completed repeat |
| `OnDelay(callback)` | Callback when initial delay ends |
| `OnStart(callback)` | Callback right after the tween starts playing |
| `OnUpdate(callback)` | Callback after each frame values are applied (receives progress) |
| `OnWait(callback)` | Patrol callback when entering wait |
| `OnBack(callback)` | Patrol callback when starting back phase |
| `IsPlaying()` | True if currently active |
| `IsPaused()` | True if paused |
| `IsFinished()` | True if stopped/destroyed |
| `IsValid()` | True while the tween is alive (not destroyed) |
| `IsDelaying()` | True while initial delay is active |
| `IsReversed()` | True if reverse mode is enabled |
| `GetType()` | Returns `SC_TYPE.TO`, `SC_TYPE.PATROL` or `SC_TYPE.NONE` |
| `GetPatrolState()` | Returns `SC_PATROL_MODE.GO`, `WAIT`, `BACK` (or `undefined`) |
| `GetProgress()` | Semantic progress (direction-aware) |
| `GetPhaseProgress()` | Raw progress for current phase (`0..1`) |
| `GetRepeatCount()` | Number of completed cycles |
| `HasTag(tag)` | Checks whether tween has a tag |

### SCMaster (Global Manager)

| Method | Description |
|--------|-------------|
| `PauseAll()` | Pause all registered tweens |
| `ResumeAll()` | Resume all paused tweens |
| `StopAll()` | Stop every registered tween |
| `DestroyAll()` | Destroy every registered tween |
| `Count()` | Number of registered tweens |
| `SetGlobalTimeScale(scale)` | Global speed multiplier |
| `GetGlobalTimeScale()` | Read global speed multiplier |
| `PauseTag(tag)` | Pause all tweens with tag |
| `ResumeTag(tag)` | Resume all tweens with tag |
| `StopTag(tag)` | Stop all tweens with tag |
| `DestroyTag(tag)` | Destroy all tweens with tag |
| `TimeScaleTag(tag, scale)` | Apply local time scale to tagged tweens |

## State Progress Model

`GetProgress()` is semantic and can be negative on return phases:

- `To`:
  - Forward: `0 -> 1`
  - Reversed: `0 -> -1`
- `Patrol`:
  - Go phase: `0 -> 1`
  - Wait phase: `1` (or `-1` if reversed)
  - Back phase: `0 -> -1`

`GetPhaseProgress()` is always raw phase progress (`0 -> 1`).

## Relative Values

`To` and `Patrol` support relative strings in end values:

- `"+100"`
- `"-40"`
- `"*2"`
- `"/2"`
- `"^2"`
- `"%3"`

Example:

```gml
new SCurve(SCURVE.LINEAR)
  .Target(self)
  .To(0.4, "x", "+48", "image_xscale", "*1.2")
  .Play();
```

## Callback Examples

```gml
new SCurve(SCURVE.EASE)
  .Target(self)
  .Patrol(0.8, 0.4, 0.2, "x", 320)
  .OnWait(function() {
    show_debug_message("Entered wait phase");
  })
  .OnBack(function() {
    show_debug_message("Starting back phase");
  })
  .OnRepeat(function(_count) {
    show_debug_message($"Repeat completed: {_count}");
  })
  .Repeat(3)
  .Play();
```

## Easing Channels

`SCURVE` enum values:

- `LINEAR`
- `EASE`
- `CUBIC`
- `QUART`
- `EXPO`
- `CIRC`
- `BACK`
- `ELASTIC`
- `BOUNCE`
- `FAST_SLOW`
- `MID_SLOW`

Animation type and patrol phase are also enums:

- `SC_TYPE`: `NONE`, `TO`, `PATROL`
- `SC_PATROL_MODE`: `GO`, `WAIT`, `BACK`

## Configuration

Debug and strict behavior is configured via macros in `scripts/Simple_Curves_Settings/Simple_Curves_Settings.gml`:

```gml
#macro SC_LOG_ALERTS true
#macro SC_LOG_ALERTS_PROPERTY true
#macro SC_LOG_ALERTS_PLAY true
#macro SC_LOG_ERRORS true
#macro SC_FATAL_ERRORS true
#macro SC_MIN_DELTA_FPS 15
#macro SC_MIN_PHASE_DURATION 0.000001
```

Both error flags can also be overridden at runtime, which is useful for release builds and test runs:

```gml
SCMaster.SetLogErrors(false);
SCMaster.SetFatalErrors(false);
```

## Convention Guide

### Tween Tags

Use tags to group tween responsibilities:

```gml
ui_anim.Tag("ui", "menu");
camera_anim.Tag("camera");
```

### Lifecycle Intent

- Use `Pause()`/`Resume()` to continue current runtime state.
- Use `Stop()` when you want a full restart on next `Play()`.
- Use `Refresh()` before `Play()` if target values changed externally.
- `Destroy()` is idempotent and releases every reference it holds; `IsValid()` tells you whether a tween is still usable.
- If the target instance disappears mid-animation, the tween is destroyed automatically instead of ticking forever.

### Patrol Timing Feel

- Long `delay` creates a hold at peak.
- Smaller `duration_back` creates a snappier return.
- `SCURVE.LINEAR` is strict and mechanical; non-linear curves feel softer.

## Examples

### UI Pop Animation

```gml
new SCurve(SCURVE.BACK)
  .Target(self)
  .To(0.25, "image_xscale", 1.15, "image_yscale", 1.15)
  .Launch(
    new SCurve(SCURVE.EASE)
      .Target(self)
      .To(0.18, "image_xscale", 1.0, "image_yscale", 1.0)
  )
  .Play();
```

### Group Pause/Resume

```gml
hud_anim.Tag("hud").Play();
score_anim.Tag("hud").Play();

SCMaster.PauseTag("hud");
SCMaster.ResumeTag("hud");
```

## Best Practices

1. Keep one tween focused on one animation responsibility.
2. Prefer tags and `SCMaster` for batch control.
3. Use `GetPhaseProgress()` when you need pure `0..1` math.
4. Use `GetProgress()` when direction semantics matter.
5. Avoid excessive debug logs in production (`SC_LOG_*`).

## Tests

The suite lives in `scripts/Simple_Curves_Tests/Simple_Curves_Tests.gml` and runs on top of Crispy. Results are written to the Output window.

Open the project, run it and the suites execute automatically. Press **Space** to run them again.

`o_test_suite` is the trigger: its Create event builds the runner, its Step event pumps the asynchronous cases, and it doubles as a disposable target instance for the lifecycle tests.

Suites:

| Suite | Covers |
|-------|--------|
| `config` | Defaults, animation types, chainability and `is_scurve()` |
| `guards` | Contract violations: invalid durations, argument pairs, tags, repeat counts and target swaps |
| `relative` | Absolute and relative end values, decimals, fallback and `Refresh()` recalculation |
| `tags` | Tag storage plus `PauseTag`/`ResumeTag`/`StopTag`/`DestroyTag`/`TimeScaleTag` |
| `manager` | Registration count, shared clock lifecycle, `StopAll`/`DestroyAll`/`PauseAll` and global time scale |
| `lifecycle` | `Destroy()` idempotency, released references and state before `Play()` |
| `animation` | Frame-driven cases: end values, auto-destroy, Patrol phases, repeats, pause/resume, stop/restart, reverse, time scale, delay, `Launch`, callbacks and destroyed targets |

Adding a test is a matter of defining one function whose name matches a suite prefix (`test_anim_...`, `test_guard_...`, ...). A name containing `_async` becomes a frame-driven case and receives `WaitStep`/`WaitBeginStep`/`WaitEndStep` checkpoints.