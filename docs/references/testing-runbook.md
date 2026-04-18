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

Windowed scene smoke:

```bash
godot --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/smoke_test.gd
```

Parse-check common edited files:

```bash
godot --headless --path sample_project --script addons/godoteer/test.gd --check-only
godot --headless --path sample_project --script addons/godoteer/test_scene.gd --check-only
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
- Scene screenshot tests should guard with `if screen.can_screenshot():`

## Headless vs Windowed

- Use headless for unit suites and fast scene checks
- Use windowed when verifying screenshot capture
- Headless mode should report `screen.can_screenshot() == false`

## Debug Loop

1. Parse-check edited GDScript
2. Run headless unit sample if assertion/lifecycle code changed
3. Run headless scene smoke if driver/screen/query code changed
4. Rerun scene smoke windowed if screenshot coverage matters
5. Update docs and both sample types in same pass when public behavior changes
