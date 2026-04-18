# Godoteer

GDScript-first Godot test harness. Write fast unit tests with `test.gd` and scene automation tests with `test_scene.gd`.

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

Run unit sample headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/unit/basic_test.gd
```

Run scene smoke headless:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
```

Run scene smoke windowed for screenshot coverage:

```bash
godot --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
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
	var start_button := screen.get_by_role("button", {"name": "Start"})

	screen.get_by_text("Idle").expect_exists()
	await start_button.click()
	await screen.find_by_text("Started")
```

Preferred queries stay accessibility-first: `get_by_role()`, `get_by_text()`, `get_by_label_text()`, `get_by_placeholder_text()`. Use `get_by_node_name()` only as implementation-detail escape hatch.
