# Testing Runbook

## Main Commands

These commands target source branch `dev`, where sample project lives.

Headless unit sample:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/unit/basic_test.gd
```

Headless scene smoke:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
```

Headless whole test tree:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --dir res://tests
```

Windowed scene smoke:

```bash
godot --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
```

Parse-check common edited files:

```bash
godot --headless --path sample_project --script addons/godoteer/locator.gd --check-only
godot --headless --path sample_project --script addons/godoteer/screen.gd --check-only
godot --headless --path sample_project --script addons/godoteer/runner.gd --check-only
godot --headless --path sample_project --script tests/unit/basic_test.gd --check-only
godot --headless --path sample_project --script tests/scene/smoke_test.gd --check-only
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
- scene failure screenshots save under `user://artifacts/failures/` when windowed capture is available

## Headless vs Windowed

- Use headless for unit suites, scene logic, and directory runs
- Use windowed when verifying screenshot behavior
- Headless mode should report `screen.can_screenshot() == false`
