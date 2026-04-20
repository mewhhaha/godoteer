# Caveats

## Accessibility Queries

- Preferred query surface is accessibility-first, not implementation-first.
- Role queries match accessible name, not node name.
- Accessible name currently uses:
  - `get_accessibility_name()` first
  - explicit `accessibility_labeled_by_nodes`
  - visible text for controls that naturally expose text
  - associated label text for pragmatic form layouts
  - never `Node.name`
- Accessible description currently uses:
  - `get_accessibility_description()` first
  - explicit `accessibility_described_by_nodes`
- `get_by_text()` matches visible rendered text only.
- `get_by_placeholder_text()` only checks textbox placeholder text.
- `get_by_label_text()` prefers explicit label relations, then falls back to pragmatic Godot layout heuristics.
- Role queries can filter by accessible `description`, `checked`, and `disabled` state.
- Exact text, label, placeholder, and accessibility comparisons do not trim edge whitespace.
- Fuzzy text-style matching still uses case-insensitive substring behavior.

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
- visual snapshot assertions compare exact PNG dimensions and pixels by default.
- visual baselines live in repo under `res://tests/__snapshots__/`.
- `--update-snapshots` is required to create or refresh baselines intentionally.
- mismatches write `actual.png` and `diff.png` under `user://artifacts/visual_failures/`.
- Crop fails hard for hidden, unsupported, or offscreen targets.

## Click Model

- `click()`, `hover()`, `focus()`, `blur()`, and `drag_to()` prefer input/focus-system routing for `Control` targets.
- `dblclick()`, `right_click()`, and `long_press()` reuse same pointer routing, with direct `gui_input` fallback when generic controls do not see parsed mouse events.
- Semantic actions still honor disabled controls and do not force activation.
- `fill()` and `press()` also refuse non-editable text inputs.
- Headless Godot may skip some GUI dispatch paths, so Godoteer keeps limited internal fallback to preserve deterministic smoke coverage.
- `select_option()` uses `OptionButton` popup flow with popup-level fallback in headless mode.
- This improves trust for common UI interactions, but is not full trace or record/replay coverage.

## Simulation Control

- `wait_until_frames()` and `wait_until_physics()` use frame budgets, not wall-clock seconds.
- `next_signal()` can capture signal payload args and poll on process or physics frames.
- `expect_signal()`, `expect_no_signal()`, and `expect_signal_count()` use short-lived signal probes, not persistent spy objects.
- `hold_action_until()` and `hold_key_until()` always release held input on success and timeout.
- `wait_for_animation_finished()`, `wait_for_audio_finished()`, `wait_for_body_entered()`, and `wait_for_area_entered()` are focused helpers over specific Godot signals, not generic scene introspection.
- `wait_for_audio_finished()` prefers `finished`, but can fall back to ended playback state when backend timing skips signal delivery.
- `pause_scene()` relies on `SceneTree.paused`; nodes configured to keep processing while paused may still run.
- `set_time_scale()` changes engine-global `Engine.time_scale` during active scene tests.
- Driver reset restores `SceneTree.paused = false` and `Engine.time_scale = 1.0`.

## Failure Model

- `expect(...)` and explicit failures collect messages and keep running.
- Good for multi-assert diagnostics.
- Bad for fail-fast expectations unless test drains or inspects failures intentionally.
- Unit and scene suites share same failure collector.
- Runner also converts new `ERROR:` and `SCRIPT ERROR:` blocks from Godot runtime log into test failures.
- This is per-test log tailing, not debugger-hook inspection. It depends on Godot file logging under `user://logs/`.
- Scene suites write failure trace bundles only when a test fails.
- Trace bundles are lightweight JSONL/text artifacts, not replayable traces.

## Missing Features

- No full OS accessibility tree dump or assistive-tech emulation APIs.
- No image diff assertions.
- No trace viewer or record/replay support.
- Low-level input helpers synthesize Godot events; they are not platform-native HID integration.

## Accessibility Inspection

- `accessibility_snapshot()` and `accessibility_tree()` are node-backed semantic views, not raw platform accessibility readback.
- `rid_valid` and `has_accessibility_element()` reflect native accessibility element availability and may differ between headless and windowed runs.
- Explicit accessibility support is forced on in sample project so debug tools and tests can inspect accessibility metadata without a live screen reader.
