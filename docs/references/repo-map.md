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
- `screen.gd`
  - queries, low-level actions, viewport and camera capture
- `locator.gd`
  - locator-first actions and waited assertions
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

- `sample_project/scenes/sample_app.tscn`
  - fixture scene with nested form row, textbox, checkbox, combobox, hidden/disabled/transient controls, drag widgets, button, and status text

## Runtime Flow

1. Godot starts with `runner.gd` via `-s`
2. Runner parses `--test` or `--dir` plus optional `--grep` and `--junit`
3. Runner loads suite files in sorted order
4. Unit suites run directly; scene suites create one driver per suite
5. Failures collect on suite object and also aggregate into grouped runner summary
6. Runner exits non-zero if any suite fails
