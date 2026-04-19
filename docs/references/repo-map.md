# Repo Map

## Purpose

Godoteer is GDScript-first harness for fast unit tests and scene automation tests with accessibility-first queries, richer form actions, and file-or-directory execution.

Branch model:

- `dev`: source branch with sample project, sample tests, docs, publish automation
- `main`: published addon branch flattened for cloning into `res://addons/godoteer/`

## Top Level

- `README.md`: short install and usage guide
- `docs/`: AI-oriented repo guide
- `sample_project/`: runnable demo project and source of truth
- `sample_project/addons/godoteer/`: harness library code
- `sample_project/tests/unit/`: unit sample suites
- `sample_project/tests/scene/`: scene smoke suites
- `sample_project/scenes/` and `sample_project/scripts/`: fixture app for scene coverage

## Harness Files

- `test_base.gd`
  - shared failure collection and `expect(...)`
- `test.gd`
  - public unit-test base
- `test_scene.gd`
  - public scene-test base
  - scene-only assertions and failure screenshots
- `driver.gd`
  - scene lifecycle owner
- `trace_recorder.gd`
  - failure-only scene trace bundle recorder
- `screen.gd`
  - queries, low-level actions, viewport and camera capture
- `locator.gd`
  - locator-first actions and waited assertions
- `locator_list.gd`
  - live collection wrapper for multi-match queries
- `runner.gd`
  - single-file or directory execution

## Sample Coverage

- `sample_project/tests/unit/basic_test.gd`
  - proves variadic `expect(...)` and detail formatting

- `sample_project/tests/scene/smoke_test.gd`
  - proves accessibility-first queries
  - proves `fill`, `clear`, `hover`, `focus`, `blur`, `drag_to`, `check`, `uncheck`, `set_checked`, `select_option`
  - proves waited locator assertions including negative/state and accessibility helpers
  - proves cropped locator screenshots, camera-targeted capture, plus failure guard for hidden targets

- `sample_project/tests/scene/visual_snapshot_test.gd`
  - proves repo-backed full-screen, locator, and camera PNG baselines
  - proves missing-baseline failure and mismatch artifact output in windowed runs

- `sample_project/tests/scene/collection_locator_test.gd`
  - proves live collection counts, positional access, delayed multi-match waits, and out-of-range failures

- `sample_project/tests/scene/accessibility_inspection_test.gd`
  - proves relation-aware accessibility queries with `description`, `checked`, and `disabled`
  - proves accessibility snapshots, accessibility tree inspection, and native accessibility element visibility

- `sample_project/tests/scene/gameplay_test.gd`
  - proves `action_press`, `action_release`, `action_tap`
  - proves `wait_physics_frames` and `wait_for_signal`
  - proves unknown action and signal-timeout failures

- `sample_project/tests/scene/gameplay_events_test.gd`
  - proves `hold_action_until`, `hold_key_until`, and `key_chord`
  - proves `dblclick`, `right_click`, and `long_press`
  - proves `expect_signal`, `expect_no_signal`, and `expect_signal_count`
  - proves waits for animation, collision overlaps, and audio completion

- `sample_project/tests/scene/simulation_test.gd`
  - proves deterministic frame-budget waits and `next_signal(...)` payload capture
  - proves `pause_scene`, `resume_scene`, `set_time_scale`, and reset cleanup

- `sample_project/tests/scene/input_matrix_test.gd`
  - proves raw keyboard, joypad, mouse wheel, relative mouse, and touch helpers
  - proves held-input cleanup across driver reset

- `sample_project/scenes/sample_app.tscn`
  - fixture scene with explicit accessibility label/description/control/flow relations plus nested form row, textbox, checkbox, combobox, hidden/disabled/transient controls, drag widgets, button, and status text

- `sample_project/scenes/gameplay_input_probe.tscn`
  - fixture scene for InputMap-driven gameplay movement and jump signal

- `sample_project/scenes/gameplay_events_probe.tscn`
  - fixture scene for held input, key chords, pointer variants, signal bursts, animation, audio, and overlap waits

- `sample_project/scenes/simulation_probe.tscn`
  - fixture scene for process/physics counters, delta sums, and signal payload timing

- `sample_project/scenes/input_matrix_probe.tscn`
  - fixture scene that records low-level input events in `_input(event)`

- `sample_project/scenes/collection_probe.tscn`
  - fixture scene for repeated text, repeated controls, repeated labels/placeholders, and delayed multi-match content

- `sample_project/trace_probes/trace_bundle_probe_test.gd`
  - dedicated pass/fail scene suite for failure trace bundle verification outside main green test tree

- `sample_project/tests/__snapshots__/`
  - checked-in visual snapshot baselines keyed by suite path, test name, and logical file name

## Runtime Flow

1. Godot starts with `runner.gd` via `-s`
2. Runner parses `--test` or `--dir` plus optional `--grep`, `--junit`, and `--update-snapshots`
3. Runner loads suite files in sorted order
4. Unit suites run directly; scene suites create one driver per suite
5. Failures collect on suite object and also aggregate into grouped runner summary
6. Runner exits non-zero if any suite fails
