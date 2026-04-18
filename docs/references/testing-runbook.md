# Testing Runbook

## Main Commands

Headless smoke run:

```bash
godot --headless --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --scene res://scenes/sample_app.tscn \
  --test res://tests/smoke_test.gd
```

Windowed smoke run:

```bash
godot --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --scene res://scenes/sample_app.tscn \
  --test res://tests/smoke_test.gd
```

## Exit Codes

- `0`: test pass
- `1`: test failure or load error after usage was valid
- `2`: CLI usage error from `runner.gd`

## Artifact Path

- Default artifacts target: `user://artifacts`
- On this machine, demo artifacts resolved under:
  - `~/.local/share/godot/app_userdata/Godoteer GDScript Demo/artifacts/`

## Headless vs Windowed

- Use headless for fast logic/integration checks.
- Use windowed for screenshot verification.
- Current `driver.can_screenshot()` returns `false` in headless mode to avoid dummy-renderer crashes.
- If a test needs screenshots, guard with `if driver.can_screenshot():`.

## Typical Failure Loop

1. Run headless smoke command.
2. If failure mentions rendering or screenshots, rerun windowed.
3. If failure mentions missing node/query, inspect sample scene tree and query semantics.
4. If failure mentions timeout, inspect whether action emitted real signal or text change.
5. Update fixture app and smoke test together when public behavior changes.

## Current Known Noise

- Godot still prints resource-leak warnings on exit after pass.
- Treat current warnings as cleanup debt, not test failure, unless behavior changes or warnings grow.

## Debugging Tips

- Add targeted `print()` or `printerr()` inside `driver.gd`, `locator.gd`, or test file.
- Prefer debugging with sample app first; it is fastest path to reproduce harness bugs.
- If click behavior looks wrong, check whether node is `BaseButton`; driver short-circuits button clicks by emitting `pressed`.
- If locator behavior looks wrong, verify whether query uses stable node name or volatile text.

## Extending Coverage

- Add new tests under `sample_project/tests/`.
- Keep one small smoke test green before adding broader scenarios.
- When adding new API surface, prove it in at least one test using public ergonomic call sites.
