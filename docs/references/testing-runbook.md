# Testing Runbook

## Main Commands

Headless smoke:

```bash
godot --headless --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --test res://tests/smoke_test.gd
```

Windowed smoke:

```bash
godot --path sample_project -s addons/godoteer_gd/runner.gd -- \
  --test res://tests/smoke_test.gd
```

Parse-check common edited files:

```bash
godot --headless --path sample_project --script addons/godoteer_gd/screen.gd --check-only
godot --headless --path sample_project --script addons/godoteer_gd/locator.gd --check-only
godot --headless --path sample_project --script tests/smoke_test.gd --check-only
```

Validate docs skill:

```bash
python3 /home/mewhhaha/.codex/skills/.system/skill-creator/scripts/quick_validate.py docs
```

## Exit Codes

- `0`: pass
- `1`: test failure or load error
- `2`: CLI usage error

## Artifact Path

- Default artifact target: `user://artifacts`
- Screenshot tests should guard with `if screen.can_screenshot():`

## Headless vs Windowed

- Use headless for fast harness checks.
- Use windowed when verifying screenshot capture.
- Headless mode should report `screen.can_screenshot() == false`.
- Smoke suite already guards screenshot path so one suite can run both modes.

## Debug Loop

1. Parse-check edited GDScript.
2. Run headless smoke.
3. If failure touches screenshots or rendering, rerun windowed.
4. If failure touches queries, inspect accessible name, visible text, placeholder, and hidden-state rules.
5. Update fixture app and smoke suite in same pass when public behavior changes.

## Current Smoke Coverage

- `get_by_role("button", {"name": "Start"})`
- `get_by_text("Idle")`
- `find_by_text("Started")`
- `get_by_label_text("Player Name")`
- `get_by_placeholder_text("Enter hero name")`
- `get_by_node_name("FormPanel")` and scoped `within(...)`
- accessibility name/description assertions
- strict `get_*` and `query_*` zero-match behavior
- screenshot guard via `can_screenshot()`
