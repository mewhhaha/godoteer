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
- `await fill(target, text)`
- `await clear(target)`
- `await press(target, keycode)`
- `await check(target)`
- `await uncheck(target)`
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
- `can_screenshot()`

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

## `GodoteerLocator`

File: `sample_project/addons/godoteer/locator.gd`

Actions:

- `await click()`
- `await fill(text)`
- `await clear()`
- `await press(keycode)`
- `await check()`
- `await uncheck()`
- `await select_option(option_text)`

Reads:

- `node()`
- `exists()`
- `text()`
- `value()`
- `property(property_name)`

Waited assertions:

- `await to_exist(timeout_sec = 2.0)`
- `await to_have_text(expected, timeout_sec = 2.0)`
- `await to_have_value(expected, timeout_sec = 2.0)`
- `await to_be_visible(timeout_sec = 2.0)`
- `await to_be_enabled(timeout_sec = 2.0)`

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

Behavior:

- rejects `--test` and `--dir` together
- discovers `.gd` suites recursively for `--dir`
- runs suite paths in sorted order
- runs `test_*` methods in sorted order
- supports mixed unit and scene suites in same directory tree
- prints grouped failure summary by suite path and test name
