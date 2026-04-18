# Godoteer

Simple Playwright-like test harness for Godot. GDScript-first path now.

Goal: run Godot scene, compose inputs, take screenshots, make assertions, exit pass/fail. No JS bridge needed for first version.

## GDScript-first shape

- Runner script extends `SceneTree`. Start from Godot CLI with `-s`.
- Test case extends `GodoteerTestCase`.
- Driver helper sends mouse/keyboard input, waits frames, reads nodes/properties, saves screenshots.
- Failures collect in GDScript and return non-zero exit code.

## Core files

- [sample_project/addons/godoteer_gd/runner.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/runner.gd)
- [sample_project/addons/godoteer_gd/test_case.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/test_case.gd)
- [sample_project/addons/godoteer_gd/driver.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/driver.gd)
- [sample_project/tests/smoke_test.gd](/home/mewhhaha/src/godoteer/sample_project/tests/smoke_test.gd)

## Run demo

```bash
godot --headless --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --scene res://scenes/sample_app.tscn \
  --test res://tests/smoke_test.gd
```

Artifacts save under `user://artifacts` inside Godot user data dir.

## Test shape

```gdscript
extends GodoteerTestCase

func run() -> void:
	var status = driver.get_by_name("StatusLabel")
	var start_button = driver.get_by_role("button", "Start")

	status.expect_exists()
	status.expect_text("Idle")
	await start_button.click()
	await status.wait_for_text("Started")
	status.expect_text("Started")
	driver.screenshot("started.png")
```

## API now

- `await driver.click(target)`
- `driver.locator(target)`
- `driver.get_by_name(name)`
- `driver.get_by_text(text)`
- `driver.get_by_role(role, name)`
- `driver.mouse_move(position)`
- `driver.mouse_button(position, button, pressed)`
- `await driver.key_tap(KEY_ENTER)`
- `await driver.wait_frames(count)`
- `await driver.wait_seconds(seconds)`
- `await driver.wait_until(predicate, timeout_sec, step_frames, message)`
- `driver.node(path_or_node)`
- `driver.node_exists(path_or_node)`
- `driver.property(path_or_node, property_name)`
- `driver.node_text(path_or_node)`
- `driver.expect_node(path_or_node, message)`
- `driver.expect_property(path_or_node, property_name, expected, message)`
- `driver.expect_text(path_or_node, expected, message)`
- `driver.screenshot(file_name)`
- `locator.exists()`, `await locator.click()`, `locator.text()`, `locator.expect_exists()`, `locator.expect_text()`, `await locator.wait_for()`, `await locator.wait_for_text()`
- `expect_true`, `expect_false`, `expect_equal`, `expect_not_null`, `expect_node`, `expect_property`

## Limits

- Node path targeting only. No selector DSL yet.
- Query layer small. Role mapping only covers common `Control` nodes now.
- Assertions collect failures; no exception-based abort yet.
- Headless mode may disable screenshot capture entirely with dummy renderer. Run windowed for visual assertions.
- Input helpers know `Control`, `Node2D`, `Vector2`. More node kinds need more adapters.

## Old JS path

JS bridge still exists in [src/godoteer.js](/home/mewhhaha/src/godoteer/src/godoteer.js). Keep as future outer harness if we want richer CI/reporting later.
