# Repo Map

## Purpose

Godoteer is GDScript-first harness for fast unit tests and scene automation tests with accessibility-first queries.

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

Source paths below are for `dev`. Published `main` branch flattens addon files from `sample_project/addons/godoteer/` to repo root.

- `sample_project/addons/godoteer/runner.gd`
  - CLI entry
  - Parses `--test` and `--artifacts`
  - Dispatches unit or scene suite based on base class

- `sample_project/addons/godoteer/test_base.gd`
  - Shared failure collection and `expect(...)`

- `sample_project/addons/godoteer/test.gd`
  - Public unit-test base

- `sample_project/addons/godoteer/test_scene.gd`
  - Public scene-test base
  - Owns scene-only assertion helpers

- `sample_project/addons/godoteer/driver.gd`
  - Session-level scene object
  - Used only for scene suites

- `sample_project/addons/godoteer/screen.gd`
  - Per-scene interaction and query layer

- `sample_project/addons/godoteer/locator.gd`
  - Strict query result wrapper and scoped locator root

## Sample Coverage

- `sample_project/tests/unit/basic_test.gd`
  - Canonical unit suite
  - Proves variadic `expect(...)`, default failure message, quiet-failure drain pattern

- `sample_project/tests/scene/smoke_test.gd`
  - Canonical scene suite
  - Proves accessibility-first queries, click flow, `find_*`, strict query semantics, screenshot guard

- `sample_project/scenes/sample_app.tscn`
  - Fixture scene used by scene smoke

## Runtime Flow

1. Godot starts with `runner.gd` via `-s`
2. Runner parses CLI args
3. Runner instantiates suite script
4. Runner determines unit vs scene base class
5. Unit suites run directly; scene suites create one `GodoteerDriver`
6. Runner discovers and executes `test_*` methods
7. Failures collect on suite object
8. Runner prints pass/fail summary and exits non-zero on failure

## Ownership Guidance

- Change `test_base.gd`, `test.gd`, `test_scene.gd` for assertion and lifecycle model
- Change `runner.gd` for suite execution contract
- Change `screen.gd` and `locator.gd` for query and interaction ergonomics
- Change fixture app and both sample test folders whenever public behavior changes
