# API Surface

Path note:

- `dev` branch stores addon under `sample_project/addons/godoteer/`
- published `main` branch flattens same files to repo root for cloning into `addons/godoteer/`

## `GodoteerBaseTest`

File: `sample_project/addons/godoteer/test_base.gd`

Shared failure and discovery behavior:

- `list_tests()`
- `record_failure(message)`
- `has_failures()`
- `failure_count()`
- `summary()`
- `drain_failures()`
- `set_failures_quiet(enabled)`
- `fail(message)`
- `expect(condition, ...details)`

## `GodoteerTest`

File: `sample_project/addons/godoteer/test.gd`

Role:

- Public base for pure unit tests

Lifecycle:

- `before_each(test_name)`
- `after_each(test_name)`

Test shape:

- `func test_*() -> void`

## `GodoteerSceneTest`

File: `sample_project/addons/godoteer/test_scene.gd`

Role:

- Public base for scene and driver tests

Lifecycle:

- `before_each(driver, test_name)`
- `after_each(driver, test_name)` resets driver by default

Scene-only helpers:

- `expect_node(path_or_node, message = "")`
- `expect_property(path_or_node, property_name, expected, message = "")`

Diagnostics:

- scene failures auto-capture screenshot when active screen exists and screenshot capture is available

## `GodoteerDriver`

File: `sample_project/addons/godoteer/driver.gd`

Methods:

- `await screen(scene_ref)`
- `await close_screen()`
- `await reset()`

## `GodoteerScreen`

File: `sample_project/addons/godoteer/screen.gd`

Timing:

- `await wait_frames(count = 1)`
- `await wait_seconds(seconds)`
- `await wait_until(predicate, timeout_sec = 2.0, step_frames = 1, message = "Condition timed out")`

Actions:

- `await click(target, button = MOUSE_BUTTON_LEFT)`
- `await hover(target)`
- `await focus(target)`
- `await blur(target)`
- `await fill(target, text)`
- `await clear(target)`
- `await drag_to(source, target_or_position, duration_sec = 0.2, steps = 12)`
- `await press(target, keycode)`
- `await check(target)`
- `await uncheck(target)`
- `await set_checked(target, checked)`
- `await select_option(target, option_text)`

Node helpers:

- `node(path_or_node)`
- `node_exists(path_or_node)`
- `property(path_or_node, property_name)`
- `node_text(path_or_node)`
- `node_value(path_or_node)`
- `is_visible(path_or_node)`
- `is_enabled(path_or_node)`
- `locator(target)`
- `within(target)`

Artifacts:

- `screenshot(file_name = "screenshot.png")`
- `capture_locator(target, file_name = "locator.png")`
- `await capture_camera(camera_target, file_name = "camera.png")`
- `can_screenshot()`

Current support matrix:

- `fill` / `clear`: `LineEdit`, `TextEdit`
- `check` / `uncheck` / `set_checked`: `CheckBox`, `CheckButton`
- `select_option`: `OptionButton`
- `focus` / `blur`: `Control`
- `capture_locator`: cropped PNG for visible `Control` targets only
- `capture_camera`: `Camera2D`, `Camera3D`
- activation actions honor disabled controls
- text entry actions honor `editable = false` on `LineEdit` / `TextEdit`
- pointer and focus helpers prefer real input/focus behavior for `Control` targets, with limited fallback when GUI dispatch does not fire
- `select_option()` remains semantic rather than popup-navigation-driven

Queries:

- `get/query/find/get_all/query_all/find_all_by_role(...)`
- `get/query/find_by_text(...)`
- `get/query/find_by_label_text(...)`
- `get/query/find_by_placeholder_text(...)`
- `get/query_by_node_name(...)`

Semantics:

- `get_*`: fail on zero or multiple, no waiting
- `query_*`: `null` on zero, fail on multiple, no waiting
- `find_*`: wait up to timeout and fail on timeout
- exact matching compares raw Godot strings with no edge trimming
- non-exact matching uses case-insensitive substring checks

## `GodoteerLocator`

File: `sample_project/addons/godoteer/locator.gd`

Actions:

- `await click()`
- `await hover()`
- `await focus()`
- `await blur()`
- `await fill(text)`
- `await clear()`
- `await drag_to(target_or_position, duration_sec = 0.2, steps = 12)`
- `await press(keycode)`
- `await check()`
- `await uncheck()`
- `await set_checked(checked)`
- `await select_option(option_text)`
- `capture(file_name = "locator.png")`

Reads:

- `node()`
- `exists()`
- `text()`
- `value()`
- `property(property_name)`

Waited assertions:

- `await to_exist(timeout_sec = 2.0)`
- `await not_to_exist(timeout_sec = 2.0)`
- `await to_have_text(expected, timeout_sec = 2.0)`
- `await not_to_have_text(expected, timeout_sec = 2.0)`
- `await to_have_value(expected, timeout_sec = 2.0)`
- `await not_to_have_value(expected, timeout_sec = 2.0)`
- `await to_be_visible(timeout_sec = 2.0)`
- `await to_be_hidden(timeout_sec = 2.0)`
- `await to_be_enabled(timeout_sec = 2.0)`
- `await to_be_disabled(timeout_sec = 2.0)`
- `await to_be_checked(timeout_sec = 2.0)`
- `await to_be_unchecked(timeout_sec = 2.0)`
- `await to_have_accessible_name(expected, timeout_sec = 2.0)`
- `await to_have_accessible_description(expected, timeout_sec = 2.0)`

Exact text and accessibility assertions compare raw strings as Godot exposes them. Leading spaces, trailing spaces, and trailing newlines stay significant.

Current instant helpers still available:

- `expect_exists()`
- `expect_text()`
- `wait_for()`
- `wait_for_text()`

## `runner.gd`

File: `sample_project/addons/godoteer/runner.gd`

Args:

- `--test <res://...>` for one file
- `--dir <res://...>` for recursive directory run
- `--artifacts <path>`
- `--grep <text>` for case-insensitive suite/test filtering
- `--junit <path>` for JUnit XML output

Behavior:

- rejects `--test` and `--dir` together
- discovers `.gd` suites recursively for `--dir`
- runs suite paths in sorted order
- runs `test_*` methods in sorted order
- filters by suite path or test name when `--grep` is set
- fails with clear runner error when `--grep` matches nothing
- supports mixed unit and scene suites in same directory tree
- prints grouped failure summary by suite path and test name
- writes JUnit XML on pass and fail when `--junit` is set
