# Godoteer

GDScript-first Godot test harness. Open scenes, drive input, query UI by accessibility-facing semantics, assert state, capture screenshots when renderer supports it.

## Installation

1. Copy [sample_project/addons/godoteer_gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd) into your project as `res://addons/godoteer_gd/`.
2. Create suite files that extend [sample_project/addons/godoteer_gd/test_case.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/test_case.gd).
3. Define `test_*` methods. Each test opens scene with `await driver.screen(...)`.
4. Run suite with [sample_project/addons/godoteer_gd/runner.gd](/home/mewhhaha/src/godoteer/sample_project/addons/godoteer_gd/runner.gd).

## Usage

Headless smoke run:

```bash
godot --headless --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --test res://tests/smoke_test.gd
```

Windowed run for screenshot coverage:

```bash
godot --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --test res://tests/smoke_test.gd
```

Minimal suite:

```gdscript
extends "res://addons/godoteer_gd/test_case.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")

func test_start_flow(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var start_button := screen.get_by_role("button", {"name": "Start"})

	screen.get_by_text("Idle").expect_exists()
	await start_button.click()
	await screen.find_by_text("Started")

	if screen.can_screenshot():
		screen.screenshot("started.png")
```

Preferred queries: `get_by_role()`, `get_by_text()`, `get_by_label_text()`, `get_by_placeholder_text()`. Use `get_by_node_name()` only as implementation-detail escape hatch.
