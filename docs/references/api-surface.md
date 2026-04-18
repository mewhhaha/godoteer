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

`expect(...)` formatting:

- no details -> `Expectation failed`
- details -> `Expectation failed: ` plus `str(...)`-joined detail list

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

Test shape:

- `func test_*(driver: GodoteerDriver) -> void`

## `GodoteerDriver`

File: `sample_project/addons/godoteer/driver.gd`

Role:

- Session-level scene object for scene suites only
- Opens and closes scene-backed `GodoteerScreen` instances

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

- `get/query/find/get_all/query_all/find_all_by_role(...)`
- `get/query/find_by_text(...)`
- `get/query/find_by_label_text(...)`
- `get/query/find_by_placeholder_text(...)`
- `get/query_by_node_name(...)`

Query semantics:

- `get_*`: fail on zero or multiple, no waiting
- `query_*`: `null` on zero, fail on multiple, no waiting
- `find_*`: wait up to timeout and fail on timeout

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

## `runner.gd`

File: `sample_project/addons/godoteer/runner.gd`

Args:

- `--test <res://...>` required
- `--artifacts <path>`

Behavior:

- Loads suite script and enforces `GodoteerTest` or `GodoteerSceneTest` inheritance
- Discovers `test_*` methods in sorted order
- Unit suites run with zero-arg tests and no driver allocation
- Scene suites create one `GodoteerDriver` and pass it to each test
- Exits `0` on pass, `1` on failure/load error, `2` on usage error
