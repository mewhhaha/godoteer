# Godoteer

GDScript-first Godot test harness. Write fast unit tests with `test.gd`, scene automation tests with `test_scene.gd`, and run one file or a whole test directory with one runner.

`dev` keeps source repo and sample project. `main` is published addon branch meant to clone into `res://addons/godoteer/`.

## Installation

From your Godot project, move into `addons/` and clone published branch there:

```bash
cd addons
git clone git@github.com:mewhhaha/godoteer.git
```

Then:

1. Create unit suites with `extends "res://addons/godoteer/test.gd"` or scene suites with `extends "res://addons/godoteer/test_scene.gd"`.
2. Define `test_*` methods.
3. Run suites with `res://addons/godoteer/runner.gd`.

Update addon later from inside `addons/godoteer`:

```bash
git pull
```

## Usage

Run one unit file headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/unit/basic_test.gd
```

Run one scene file headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
```

Run filtered tests or write JUnit:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --dir res://tests --grep drag --junit user://artifacts/junit/results.xml
```

Update visual baselines intentionally:

```bash
godot --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/visual_snapshot_test.gd --update-snapshots
```

Run whole test tree:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --dir res://tests
```

`--dir` discovers only scripts that extend `res://addons/godoteer/test.gd` or `test_scene.gd` and define `test_*`. Helper base scripts and ordinary app scripts are skipped.

Run scene smoke windowed for screenshot coverage:

```bash
godot --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
```

Run gameplay-focused scene test headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/gameplay_test.gd
```

Run gameplay-events scene test headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/gameplay_events_test.gd
```

Run deterministic simulation scene test headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/simulation_test.gd
```

Minimal unit suite:

```gdscript
extends "res://addons/godoteer/test.gd"

func test_set_membership() -> void:
	var actual := {"a": true, "b": true}
	var expected := {"a": true, "b": true}
	expect(actual == expected, "set mismatch", "actual=", actual, "expected=", expected)
```

Minimal scene suite:

```gdscript
extends "res://addons/godoteer/test_scene.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")

func test_start_flow(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var name_field := screen.get_by_role("textbox", {"name": "Player Name"})
	var start_button := screen.get_by_role("button", {"name": "Start"})

	await name_field.fill("Mew")
	await start_button.click()
	await screen.find_by_text("Started Mew / Pending / Mage")
```

Gameplay action example:

```gdscript
extends "res://addons/godoteer/test_scene.gd"

const GAMEPLAY_INPUT_PROBE := preload("res://scenes/gameplay_input_probe.tscn")

func test_move_and_jump(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_INPUT_PROBE)
	var gameplay := screen.get_by_node_name("GameplayInputProbe").node()

	screen.action_press("move_right")
	await screen.wait_physics_frames(4)
	screen.action_release("move_right")

	screen.action_press("jump")
	await screen.wait_for_signal(gameplay, "jumped")
	screen.action_release("jump")
```

Gameplay interaction example:

```gdscript
extends "res://addons/godoteer/test_scene.gd"

const GAMEPLAY_EVENTS_PROBE := preload("res://scenes/gameplay_events_probe.tscn")

func test_double_click_and_signal_counts(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_EVENTS_PROBE)
	var probe := screen.get_by_node_name("GameplayEventsProbe").node()
	var pointer_target := screen.get_by_node_name("PointerTarget")

	await pointer_target.dblclick()
	probe.start_process_burst(3, "burst")
	var history := await screen.expect_signal_count(probe, "probe_signal", 3, 12)
	expect(history.size() == 3, "burst should emit three signals")
```

Deterministic simulation example:

```gdscript
extends "res://addons/godoteer/test_scene.gd"

const SIMULATION_PROBE := preload("res://scenes/simulation_probe.tscn")

func test_process_and_physics_progress(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SIMULATION_PROBE)
	var probe := screen.get_by_node_name("SimulationProbe").node()

	await screen.wait_until_frames(func() -> bool: return probe.process_count >= 3, 30)
	var pulse := await screen.next_signal(probe, "physics_pulse", 30, true)
	expect(pulse["fired"], "physics pulse should arrive")
```

Useful scene actions:
- `await locator.dblclick(button = MOUSE_BUTTON_LEFT)`
- `await locator.right_click()`
- `await locator.fill(text)`
- `await locator.clear()`
- `await locator.hover()`
- `await locator.focus()`
- `await locator.blur()`
- `await locator.long_press(hold_frames = 12, button = MOUSE_BUTTON_LEFT)`
- `await locator.drag_to(target_or_position)`
- `await locator.press(keycode)`
- `await locator.check()`
- `await locator.uncheck()`
- `await locator.set_checked(bool)`
- `await locator.select_option(option_text)`
- `await locator.capture(file_name)`
- `locator.expect_snapshot(file_name, options = {})`
- `await screen.capture_camera(camera, file_name)`
- `screen.expect_snapshot(file_name, options = {})`
- `await screen.expect_camera_snapshot(camera, file_name, options = {})`
- `screen.action_press(action_name, strength = 1.0)`
- `screen.action_release(action_name)`
- `await screen.action_tap(action_name, hold_frames = 1, strength = 1.0)`
- `screen.key_press(keycode)`
- `screen.key_release(keycode)`
- `await screen.key_tap(keycode, hold_frames = 1)`
- `await screen.hold_key_until(keycode, predicate, max_frames = 120)`
- `await screen.key_chord(keycodes, hold_frames = 1)`
- `screen.joy_button_press(button, device = 0)`
- `screen.joy_button_release(button, device = 0)`
- `await screen.joy_button_tap(button, hold_frames = 1, device = 0)`
- `screen.joy_axis_set(axis, value, device = 0)`
- `screen.joy_axis_reset(axis, device = 0)`
- `screen.mouse_move_relative(delta)`
- `await screen.mouse_wheel(vertical_steps, horizontal_steps = 0, target = null)`
- `screen.touch_press(position, index = 0)`
- `screen.touch_move(position, index = 0)`
- `screen.touch_release(position, index = 0)`
- `await screen.touch_tap(position, index = 0, hold_frames = 1)`
- `await screen.touch_drag(from, to, index = 0, duration_sec = 0.2, steps = 12)`
- `await screen.touch_pinch(start_a, start_b, end_a, end_b, duration_sec = 0.2, steps = 12, index_a = 0, index_b = 1)`
- `await screen.hold_action_until(action_name, predicate, max_frames = 120, strength = 1.0)`
- `await screen.expect_signal(target, signal_name, max_frames = 120, physics = false)`
- `await screen.expect_no_signal(target, signal_name, max_frames = 120, physics = false)`
- `await screen.expect_signal_count(target, signal_name, expected_count, max_frames = 120, physics = false)`
- `await screen.wait_for_animation_finished(player, animation_name = "", max_frames = 120)`
- `await screen.wait_for_audio_finished(player, max_frames = 120)`
- `await screen.wait_for_body_entered(area, max_frames = 120)`
- `await screen.wait_for_area_entered(area, max_frames = 120)`

Semantic actions still respect control state. Disabled controls refuse activation, and text entry helpers refuse non-editable `LineEdit` / `TextEdit` targets.

Pointer and focus helpers prefer event-driven routing for `Control` targets, with limited internal fallback where headless Godot does not dispatch GUI input. `select_option()` now uses `OptionButton` popup flow with popup-level fallback for headless determinism.

Prefer frame-budget waits for gameplay and simulation tests. `wait_seconds`, `wait_until(timeout_sec)`, and `wait_for_signal(timeout_sec)` stay available for wall-clock cases.

Role queries also accept accessibility-state filters like `description`, `checked`, and `disabled`. Current matching stays node-backed and headless-friendly.

Useful waited locator assertions:
- `await locator.to_exist()`
- `await locator.not_to_exist()`
- `await locator.to_have_text(text)`
- `await locator.not_to_have_text(text)`
- `await locator.to_have_value(value)`
- `await locator.not_to_have_value(value)`
- `await locator.to_be_visible()`
- `await locator.to_be_hidden()`
- `await locator.to_be_enabled()`
- `await locator.to_be_disabled()`
- `await locator.to_be_checked()`
- `await locator.to_be_unchecked()`
- `await locator.to_have_accessible_name(text)`
- `await locator.to_have_accessible_description(text)`
- `await locator.to_have_accessibility_role(role)`

Collection queries now return live `GodoteerLocatorList`, not raw arrays:

```gdscript
var buttons := screen.get_all_by_role("button", {"name": "Choice"})
await buttons.to_have_count(2)
await buttons.nth(1).click()
for button in buttons.all():
	expect(button.exists(), "button should still resolve")
```

Collection helpers:
- `count()`
- `is_empty()`
- `all()`
- `nth(index)`
- `first()`
- `last()`
- `await to_have_count(expected, timeout_sec = 2.0)`
- `await to_be_empty(timeout_sec = 2.0)`

`get_all_*`, `query_all_*`, and `find_all_*` no longer return raw `Array`. Use `.all()` when manual iteration needs array semantics.

Useful timing helpers:
- `await screen.wait_frames(count)`
- `await screen.wait_physics_frames(count)`
- `await screen.wait_seconds(seconds)`
- `await screen.wait_until_frames(predicate, max_frames = 120)`
- `await screen.wait_until_physics(predicate, max_frames = 120)`
- `await screen.wait_until(predicate, timeout_sec = 2.0)`
- `await screen.next_signal(target, signal_name, max_frames = 120, physics = false)`
- `await screen.wait_for_signal(target, signal_name, timeout_sec = 2.0)`
- `screen.pause_scene()`
- `screen.resume_scene()`
- `screen.set_time_scale(scale)`

Low-level input example:

```gdscript
extends "res://addons/godoteer/test_scene.gd"

const INPUT_MATRIX_PROBE := preload("res://scenes/input_matrix_probe.tscn")

func test_raw_input(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(INPUT_MATRIX_PROBE)

	screen.key_press(KEY_A)
	await screen.wait_frames(1)
	screen.key_release(KEY_A)
	screen.joy_axis_set(JOY_AXIS_LEFT_X, 0.8)
	await screen.mouse_wheel(1)
	await screen.touch_tap(Vector2(32, 32))
```

Preferred queries stay accessibility-first: `get_by_role()`, `get_by_text()`, `get_by_label_text()`, `get_by_placeholder_text()`. Use `get_by_node_name()` only as implementation-detail escape hatch.

Exact query and assertion matches use raw Godot strings. Godoteer does not trim edge whitespace for visible text, labels, placeholders, `accessibility_name`, or `accessibility_description`. Fuzzy matching still uses case-insensitive substring checks.

Accessibility inspection helpers:
- `screen.accessibility_rid(target)`
- `screen.has_accessibility_element(target)`
- `screen.accessibility_snapshot(target)`
- `screen.accessibility_tree(root_target = null, options = {})`
- `screen.expect_has_accessibility_element(target)`
- `screen.expect_accessibility_role(target, role)`

`rid_valid` and `has_accessibility_element()` reflect native accessibility element availability. They may differ between headless and windowed runs even when query behavior stays the same.

`locator.capture(file_name)` saves cropped PNGs for visible `Control` targets in windowed runs. `screen.screenshot(file_name)` stays full-screen. `screen.capture_camera(camera, file_name)` captures from a specific `Camera2D` or `Camera3D`.

Visual assertions layer on top of capture:
- baselines live under `sample_project/tests/__snapshots__/`
- normal runs fail on missing or mismatched baseline PNGs
- `--update-snapshots` creates or refreshes baselines intentionally
- mismatches write `actual.png` and `diff.png` under `user://artifacts/visual_failures/`
- matching is exact-pixel by default, with optional `max_diff_pixels`

Scene test failures also write trace bundles:
- `user://artifacts/traces/<suite>/<test>/trace.jsonl`
- `user://artifacts/traces/<suite>/<test>/summary.txt`
- failure output includes `Failure trace: ...`
- traces write on failure only, not on pass
