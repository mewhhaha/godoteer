# Repo Map

## Purpose

Godoteer is GDScript-first harness for driving Godot scenes, composing input, querying UI by accessibility-facing semantics, asserting state, and taking screenshots when renderer supports it.

## Top Level

- `README.md`: short install and usage guide.
- `docs/`: AI-oriented repo guide.
- `sample_project/`: runnable demo project and current source of truth.
- `sample_project/addons/godoteer_gd/`: harness library code.
- `sample_project/tests/`: smoke coverage for public API.
- `sample_project/scenes/` and `sample_project/scripts/`: fixture app used by smoke tests.

## Harness Files

- `sample_project/addons/godoteer_gd/runner.gd`
  - CLI entry.
  - Parses `--test` and `--artifacts`.
  - Discovers `test_*` methods.
  - Creates one `GodoteerDriver` per suite run.

- `sample_project/addons/godoteer_gd/test_case.gd`
  - Suite base class.
  - Owns collected failure list.
  - Exposes lifecycle hooks and assertion helpers.

- `sample_project/addons/godoteer_gd/driver.gd`
  - Session-level object passed into each `test_*`.
  - Opens and closes scene-backed `GodoteerScreen` instances.

- `sample_project/addons/godoteer_gd/screen.gd`
  - Per-scene interaction and query layer.
  - Composes input.
  - Resolves accessibility-first queries.
  - Exposes screenshot and accessibility inspection helpers.

- `sample_project/addons/godoteer_gd/locator.gd`
  - Strict query result wrapper.
  - Adds click/assert/wait helpers.
  - Doubles as scoped query root via `within()`.

## Fixture App

- `sample_project/scenes/sample_app.tscn`
  - `Control` root named `SampleApp`
  - `VBoxContainer` named `FormPanel`
  - `StatusLabel` starts with visible text `Idle`
  - `NameInput` exposes label and placeholder coverage
  - `ActionButton` exposes accessible name/description coverage

- `sample_project/scripts/sample_app.gd`
  - Connects Start button press to delayed status update.
  - Delay exists so `find_*` polling gets real coverage.

- `sample_project/tests/smoke_test.gd`
  - Canonical accessibility-first suite.
  - Proves role/name, visible text, label text, placeholder text, node-name escape hatch, accessibility assertions, strict query semantics, screenshot guard.

## Runtime Flow

1. Godot starts with `runner.gd` via `-s`.
2. Runner parses CLI args.
3. Runner instantiates suite script.
4. Runner creates one `GodoteerDriver`.
5. Runner discovers all `test_*` methods.
6. Each test picks scene with `await driver.screen(...)`.
7. Failures collect on suite object.
8. Runner prints pass/fail summary and exits non-zero on failure.

## Ownership Guidance

- Change `screen.gd` for query semantics, input primitives, accessibility helpers.
- Change `locator.gd` for ergonomic API shape and scoped queries.
- Change `driver.gd` for screen lifecycle behavior.
- Change `test_case.gd` for assertion/failure model.
- Change `runner.gd` for CLI contract or suite execution.
- Change fixture app and smoke suite whenever public API behavior changes.
