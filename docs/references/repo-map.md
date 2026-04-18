# Repo Map

## Purpose

Godoteer is a GDScript-first harness for driving Godot scenes, composing input, waiting on UI state, taking screenshots, and reporting pass/fail from the CLI.

## Top Level

- `README.md`: human-readable quick start and current public API summary.
- `docs/`: AI-oriented repo guide. Start here when building context.
- `sample_project/`: runnable demo project and current source of truth.
- `sample_project/addons/godoteer_gd/`: harness library code.
- `sample_project/tests/`: integration tests that exercise public ergonomics.
- `sample_project/scenes/` and `sample_project/scripts/`: tiny fixture app used by smoke coverage.

## Harness Files

- `sample_project/addons/godoteer_gd/runner.gd`
  - Entry point for CLI runs.
  - Parses `OS.get_cmdline_user_args()`.
  - Loads scene and test script.
  - Binds `GodoteerDriver` into `GodoteerTestCase`.
  - Exits with `0`, `1`, or `2`.

- `sample_project/addons/godoteer_gd/test_case.gd`
  - Base class for tests.
  - Owns failure list.
  - Exposes assertion helpers and lifecycle hooks.

- `sample_project/addons/godoteer_gd/driver.gd`
  - Main interaction layer.
  - Sends input events.
  - Resolves locators and node paths.
  - Reads properties and text.
  - Captures screenshots when renderer supports it.

- `sample_project/addons/godoteer_gd/locator.gd`
  - Playwright/testing-library-like wrapper over driver queries.
  - Adds `click`, `expect_exists`, `expect_text`, `wait_for`, `wait_for_text`.

## Fixture App

- `sample_project/scenes/sample_app.tscn`
  - `Control` root named `SampleApp`
  - `Label` child `StatusLabel` starts with text `Idle`
  - `Button` child `ActionButton` shows text `Start`

- `sample_project/scripts/sample_app.gd`
  - Connects button press to label update.
  - Press flow changes `StatusLabel.text` from `Idle` to `Started`.

- `sample_project/tests/smoke_test.gd`
  - Canonical integration test.
  - Exercises locator queries, click, wait-for-text, assertion helpers, screenshot gating.

## Runtime Flow

1. Godot starts with `runner.gd` via `-s`.
2. Runner parses `--scene`, `--test`, `--artifacts`.
3. Runner instantiates scene, then test.
4. Runner creates `GodoteerDriver` and binds it into test case.
5. Test performs actions and assertions.
6. Test case accumulates failures.
7. Runner prints `PASS` or failure summary and exits non-zero on failure.

## Ownership Guidance

- Change `driver.gd` for interaction primitives or query semantics.
- Change `locator.gd` for ergonomic API surface.
- Change `test_case.gd` for assertion style or lifecycle behavior.
- Change `runner.gd` for CLI contract, startup, shutdown, or artifact routing.
- Change sample scene/script/test when updating or proving public behavior.
