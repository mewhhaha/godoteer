# Caveats

## Screenshot Caveat

- Headless Godot on this setup uses dummy rendering.
- `Viewport.get_texture()` may be null in headless mode.
- `screen.can_screenshot()` guards against this and should stay in sync with real renderer behavior.
- Use windowed runs for visual assertions.

## Query Caveats

- `get_by_text()` is volatile by design; it tracks current rendered text, not stable identity.
- Prefer `get_by_name()` or `get_by_role()` when text changes during test flow.
- `get_by_name()` currently matches node name or visible text, so collisions are possible.
- Queries return first depth-first match only. No nth-match, all-match, or scoped `within()` helper yet.

## Assertion Model

- Assertions collect into `failures` and continue running.
- This is good for multi-assert diagnostics but can let later steps run after earlier breakage.
- If you add fail-fast behavior, update docs and tests together.

## Click Model

- `BaseButton` clicks are semantic, not physical.
- Driver emits `pressed` directly because composed mouse input was unreliable for buttons.
- This means button coverage proves user-intent flow, not low-level event propagation.

## Mouse Motion Model

- Mouse motion uses interpolated `InputEventMouseMotion` events.
- Duration is approximate because timing still depends on Godot timers and frame scheduling.
- `move_mouse_to()` starts from tracked `last_mouse_position`, which defaults to `Vector2.ZERO` until first motion or button event.

## Cleanup Warnings

- Passing runs still emit Godot resource-leak warnings at exit.
- Do not silently suppress them without understanding root cause.
- If you work on shutdown, rerun smoke before and after to ensure exit codes stay stable.

## Missing Features

- No selector DSL beyond current locators.
- No drag/drop helper.
- No image diff assertions.
- No trace or record/replay support.
- No multi-match locator API.
- No scoped query helper like `within(container)`.

## Safe Next Extensions

- Add `within(root).get_by_role(...)` by threading `root_target` through existing queries.
- Add richer role mapping for more Godot `Control` subclasses.
- Add `expect(locator).to_have_text(...)` sugar on top of current locator methods.
- Add dedicated screenshot assertions only after renderer-mode handling is stable.
