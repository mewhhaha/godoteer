# Godoteer

GDScript-first test harness for Godot. Run scenes, compose input, assert state, and capture screenshots from Godot CLI.

## Installation

1. Copy [sample_project/addons/godoteer_gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd) into your Godot project as `res://addons/godoteer_gd/`.
2. Create test files that extend [test_case.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/test_case.gd).
3. Run tests with [runner.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/runner.gd).

## Usage

Run sample smoke test headless:

```bash
godot --headless --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --scene res://scenes/sample_app.tscn \
  --test res://tests/smoke_test.gd
```

Run windowed when you need screenshots:

```bash
godot --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --scene res://scenes/sample_app.tscn \
  --test res://tests/smoke_test.gd
```

Minimal test:

```gdscript
extends "res://addons/godoteer_gd/test_case.gd"

func run(screen: GodoteerDriver) -> void:
	var status = screen.get_by_name("StatusLabel")
	var start_button = screen.get_by_role("button", "Start")

	status.expect_text("Idle")
	await screen.move_mouse_between(Vector2(0, 0), Vector2(110, 120), 0.2, 12)
	await start_button.click()
	await status.wait_for_text("Started")
	status.expect_text("Started")

	if screen.can_screenshot():
		screen.screenshot("started.png")
```

Artifacts save under `user://artifacts`. Headless runs skip real screenshot capture on dummy renderer; use windowed mode for visual assertions.
