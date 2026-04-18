# API Surface

Path note:

- `dev` branch stores addon under `sample_project/addons/godoteer/`
- published `main` branch flattens same files to repo root for cloning into `addons/godoteer/`

## `GodoteerTestCase`

File: `sample_project/addons/godoteer/test_case.gd`

Lifecycle:

- `before_each(driver, test_name)`
- `after_each(driver, test_name)`
- `list_tests()`

Assertions and failure helpers:

- `fail(message)`
- `expect_true(condition, message)`
- `expect_false(condition, message)`
- `expect_equal(actual, expected, message)`
- `expect_not_null(value, message)`
- `expect_node(path_or_node, message)`
- `expect_property(path_or_node, property_name, expected, message)`
- `drain_failures()`
- `set_failures_quiet(enabled)`

Behavior:

- Suite files expose `test_*` methods.
- Assertions collect failures instead of aborting immediately.
- `drain_failures()` exists so smoke tests can verify expected failures from strict `get_*` semantics.

## `GodoteerDriver`

File: `sample_project/addons/godoteer/driver.gd`

Role:

- Session-level suite object.
- Opens and closes scene-backed `GodoteerScreen` instances.

Methods:

- `await screen(scene_ref)`
- `await close_screen()`
- `await reset()`

Accepted scene refs:

- `PackedScene`
- `res://...` path string

## `GodoteerScreen`

File: `sample_project/addons/godoteer/screen.gd`

Timing:

- `await wait_frames(count = 1)`
- `await wait_seconds(seconds)`
- `await wait_until(predicate, timeout_sec = 2.0, step_frames = 1, message = "Condition timed out")`

Raw access:

- `node(path_or_node)`
- `node_exists(path_or_node)`
- `property(path_or_node, property_name)`
- `node_text(path_or_node)`
- `locator(target)`
- `within(target)`

Input and artifacts:

- `await click(target, button = MOUSE_BUTTON_LEFT)`
- `mouse_move(position)`
- `await move_mouse_between(from_position, to_position, duration_sec = 0.2, steps = 12)`
- `await move_mouse_to(to_position, duration_sec = 0.2, steps = 12)`
- `mouse_button(position, button = MOUSE_BUTTON_LEFT, pressed = true)`
- `await key_tap(keycode)`
- `screenshot(file_name = "screenshot.png")`
- `can_screenshot()`

Accessibility helpers:

- `screen_reader_supported()`
- `screen_reader_active()`
- `accessible_name(target)`
- `accessible_description(target)`
- `expect_accessible_name(target, expected, message = "")`
- `expect_accessible_description(target, expected, message = "")`

Accessibility-first queries:

- Role:
  - `get_by_role(role, options = {})`
  - `query_by_role(role, options = {})`
  - `find_by_role(role, options = {})`
  - `get_all_by_role(role, options = {})`
  - `query_all_by_role(role, options = {})`
  - `find_all_by_role(role, options = {})`
- Visible text:
  - `get_by_text(text, options = {})`
  - `query_by_text(text, options = {})`
  - `find_by_text(text, options = {})`
- Label text:
  - `get_by_label_text(text, options = {})`
  - `query_by_label_text(text, options = {})`
  - `find_by_label_text(text, options = {})`
- Placeholder text:
  - `get_by_placeholder_text(text, options = {})`
  - `query_by_placeholder_text(text, options = {})`
  - `find_by_placeholder_text(text, options = {})`
- Escape hatch:
  - `get_by_node_name(name, root_target = null)`
  - `query_by_node_name(name, root_target = null)`

Query options:

- `name`: only for role queries
- `exact`: default `true`
- `include_hidden`: default `false`

Cardinality semantics:

- `get_*`: fail on zero or multiple
- `query_*`: `null` on zero, fail on multiple
- `find_*`: poll until exact single match, fail on timeout
- `get_all_*`: fail on zero
- `query_all_*`: empty array on zero
- `find_all_*`: poll until at least one match

Matching model:

- Role name matching uses accessible name, not node name.
- Accessible name order:
  - `Control.accessibility_name`
  - visible text for controls that naturally expose text
  - never raw node name
- `get_by_text()` matches visible rendered text only.
- `get_by_placeholder_text()` matches textbox placeholder text only.
- `get_by_node_name()` matches `Node.name` only and is not preferred.

Current role mapping:

- `CheckBox`, `CheckButton` -> `checkbox`
- `OptionButton` -> `combobox`
- `LineEdit`, `TextEdit` -> `textbox`
- `BaseButton` -> `button`
- `Label`, `RichTextLabel` -> `text`

## `GodoteerLocator`

File: `sample_project/addons/godoteer/locator.gd`

Locator methods:

- `node()`
- `exists()`
- `await click()`
- `property(property_name)`
- `text()`
- `expect_exists(message = "")`
- `expect_text(expected, message = "")`
- `await wait_for(timeout_sec = 2.0, step_frames = 1, message = "")`
- `await wait_for_text(expected, timeout_sec = 2.0, step_frames = 1, message = "")`
- `within()`

Scoped query helpers:

- `get/query/find/get_all/query_all/find_all_by_role(...)`
- `get/query/find_by_text(...)`
- `get/query/find_by_label_text(...)`
- `get/query/find_by_placeholder_text(...)`
- `get/query_by_node_name(...)`

Behavior:

- Locator usually wraps one strict query result.
- Locator can also act as scoped root for `within()` and child queries.

## `runner.gd`

File: `sample_project/addons/godoteer/runner.gd`

Args:

- `--test <res://...>` required
- `--artifacts <path>`

Behavior:

- Loads suite script and enforces `GodoteerTestCase` inheritance.
- Discovers `test_*` methods in sorted order.
- Passes one `GodoteerDriver` session into each test method.
- Exits `0` on pass, `1` on failure/load error, `2` on usage error.
