# API Surface

## `GodoteerTestCase`

File: `sample_project/addons/godoteer_gd/test_case.gd`

Lifecycle:

- `before_each(screen)`
- `run(screen)`
- `after_each(screen)`
- `execute()` runs those in order

State:

- `screen`: bound `GodoteerDriver`
- `app_root`: loaded scene root
- `failures`: collected failure messages

Assertions:

- `fail(message)`
- `expect_true(condition, message)`
- `expect_false(condition, message)`
- `expect_equal(actual, expected, message)`
- `expect_not_null(value, message)`
- `expect_node(path_or_node, message)`
- `expect_property(path_or_node, property_name, expected, message)`

Behavior:

- Assertions append to `failures`; they do not abort immediately.
- `summary()` joins failures with newlines.

## `GodoteerDriver`

File: `sample_project/addons/godoteer_gd/driver.gd`

Timing:

- `await wait_frames(count = 1)`
- `await wait_seconds(seconds)`
- `await wait_until(predicate, timeout_sec = 2.0, step_frames = 1, message = "Condition timed out")`

Node and property access:

- `node(path_or_node)`
- `node_exists(path_or_node)`
- `property(path_or_node, property_name)`
- `node_text(path_or_node)`

Actions:

- `await click(target, button = MOUSE_BUTTON_LEFT)`
- `mouse_move(position)`
- `await move_mouse_between(from_position, to_position, duration_sec = 0.2, steps = 12)`
- `await move_mouse_to(to_position, duration_sec = 0.2, steps = 12)`
- `mouse_button(position, button = MOUSE_BUTTON_LEFT, pressed = true)`
- `await key_tap(keycode)`

Artifacts:

- `screenshot(file_name = "screenshot.png")`
- `can_screenshot()`

Queries:

- `locator(target)`
- `get_by_name(name, root_target = null)`
- `get_by_text(text, root_target = null)`
- `get_by_role(role, name = "", root_target = null)`

Driver assertions:

- `expect_node(path_or_node, message = "")`
- `expect_property(path_or_node, property_name, expected, message = "")`
- `expect_text(path_or_node, expected, message = "")`

Query internals:

- `resolve_query(query)` handles `target`, `name`, `text`, `role`
- `name` query matches `candidate.name` or current text
- `text` query matches current `node_text(candidate)`
- `role` query uses `_node_role()` mapping plus optional name/text match

Current role mapping:

- `CheckBox`, `CheckButton` -> `checkbox`
- `OptionButton` -> `combobox`
- `LineEdit`, `TextEdit` -> `textbox`
- `BaseButton` -> `button`
- `Label`, `RichTextLabel` -> `text`

Click semantics:

- `BaseButton` does not receive composed mouse events.
- Driver emits `pressed` directly after `grab_focus()`.
- Other supported targets resolve to `Control` center point, `Node2D.global_position`, or explicit `Vector2`.

Mouse motion semantics:

- Driver tracks `last_mouse_position`.
- `move_mouse_between()` interpolates from point A to point B.
- Duration is explicit in seconds.
- `steps` controls how many intermediate motion events get emitted.

## `GodoteerLocator`

File: `sample_project/addons/godoteer_gd/locator.gd`

Methods:

- `node()`
- `exists()`
- `await click()`
- `property(property_name)`
- `text()`
- `expect_exists(message = "")`
- `expect_text(expected, message = "")`
- `await wait_for(timeout_sec = 2.0, step_frames = 1, message = "")`
- `await wait_for_text(expected, timeout_sec = 2.0, step_frames = 1, message = "")`

Guidance:

- Use locator methods in tests for public-facing ergonomics.
- Use driver internals when extending harness itself.

## `runner.gd`

File: `sample_project/addons/godoteer_gd/runner.gd`

Accepted args:

- `--scene <res://...>`
- `--test <res://...>` required
- `--artifacts <path>`

Behavior:

- Loads scene if provided; otherwise uses root.
- Instantiates test script and enforces `GodoteerTestCase` inheritance.
- Prints one-line start and one-line pass summary, or failure count plus summary.
