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

Run whole test tree:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --dir res://tests
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
	var name_field := screen.get_by_role("textbox", {"name": "Player Name"})
	var start_button := screen.get_by_role("button", {"name": "Start"})

	await name_field.fill("Mew")
	await start_button.click()
	await screen.find_by_text("Started Mew / Pending / Mage")
```

Useful scene actions:
- `await locator.fill(text)`
- `await locator.clear()`
- `await locator.hover()`
- `await locator.focus()`
- `await locator.blur()`
- `await locator.drag_to(target_or_position)`
- `await locator.press(keycode)`
- `await locator.check()`
- `await locator.uncheck()`
- `await locator.set_checked(bool)`
- `await locator.select_option(option_text)`
- `await locator.capture(file_name)`

Useful waited locator assertions:
- `await locator.to_exist()`
- `await locator.not_to_exist()`
- `await locator.to_have_text(text)`
- `await locator.not_to_have_text(text)`
- `await locator.to_have_value(value)`
- `await locator.to_be_visible()`
- `await locator.to_be_hidden()`
- `await locator.to_be_enabled()`
- `await locator.to_be_disabled()`
- `await locator.to_be_checked()`

Preferred queries stay accessibility-first: `get_by_role()`, `get_by_text()`, `get_by_label_text()`, `get_by_placeholder_text()`. Use `get_by_node_name()` only as implementation-detail escape hatch.
