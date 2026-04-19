# Caveats

## Accessibility Queries

- Preferred query surface is accessibility-first, not implementation-first.
- Role queries match accessible name, not node name.
- Accessible name currently uses:
  - `accessibility_name` first
  - visible text for controls that naturally expose text
  - associated label text for pragmatic form layouts
  - never `Node.name`
- `get_by_text()` matches visible rendered text only.
- `get_by_placeholder_text()` only checks textbox placeholder text.
- `get_by_label_text()` is pragmatic Godot version, not full browser-label model.

## Strict Cardinality

- `get_*` fails on zero or multiple matches.
- `query_*` returns `null` on zero, still fails on multiple.
- `find_*` polls up to default `2.0s`.
- Smoke suite uses `drain_failures()` for expected-failure coverage. That helper is test-only support, not main product API.

## Node Name Escape Hatch

- `get_by_node_name()` still exists for debugging and implementation-detail lookups.
- Do not treat node-name queries as preferred docs/examples path.
- If public docs start leaning on node names, API drift started.

## Hidden State

- Queries exclude hidden `CanvasItem` nodes by default.
- `include_hidden = true` opts role/text/label/placeholder queries into hidden nodes.
- Hidden semantics are conservative Godot approximation, not browser-exact ARIA tree behavior.

## Screenshot Caveat

- Headless Godot on this setup uses dummy rendering.
- `Viewport.get_texture()` may be null in headless mode.
- `screen.can_screenshot()` guards screenshot capture and should stay honest.
- Use windowed runs for visual assertions.
- `locator.capture(...)` crops visible `Control` targets only.
- `screen.capture_camera(...)` captures full camera viewport, not cropped node regions.
- Crop fails hard for hidden, unsupported, or offscreen targets.

## Click Model

- `BaseButton` clicks are semantic, not fully physical.
- Harness emits `pressed` directly after `grab_focus()`.
- This keeps button tests stable, but does not prove low-level pointer event routing.

## Failure Model

- `expect(...)` and explicit failures collect messages and keep running.
- Good for multi-assert diagnostics.
- Bad for fail-fast expectations unless test drains or inspects failures intentionally.
- Unit and scene suites share same failure collector.

## Missing Features

- No DOM-like accessibility tree traversal APIs.
- No image diff assertions.
- No trace or record/replay support.
