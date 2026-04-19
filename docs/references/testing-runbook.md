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

Headless accessibility inspection scene test:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/accessibility_inspection_test.gd
```

Headless gameplay scene test:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/gameplay_test.gd
```

Headless gameplay-events scene test:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/gameplay_events_test.gd
```

Headless deterministic simulation scene test:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/simulation_test.gd
```

Headless low-level input scene test:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/input_matrix_test.gd
```

Filtered run with JUnit output:

```bash
godot --headless --path sample_project -s addons/godoteer/runner.gd -- \
  --dir res://tests --grep drag --junit user://artifacts/junit/results.xml
```

Update visual baselines intentionally:

```bash
godot --path sample_project -s addons/godoteer/runner.gd -- \
  --test res://tests/scene/visual_snapshot_test.gd --update-snapshots
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
godot --headless --path sample_project --script tests/scene/accessibility_inspection_test.gd --check-only
godot --headless --path sample_project --script scripts/gameplay_input_probe.gd --check-only
godot --headless --path sample_project --script tests/scene/gameplay_test.gd --check-only
godot --headless --path sample_project --script scripts/gameplay_events_probe.gd --check-only
godot --headless --path sample_project --script tests/scene/gameplay_events_test.gd --check-only
godot --headless --path sample_project --script scripts/simulation_probe.gd --check-only
godot --headless --path sample_project --script tests/scene/simulation_test.gd --check-only
godot --headless --path sample_project --script scripts/input_matrix_probe.gd --check-only
godot --headless --path sample_project --script tests/scene/input_matrix_test.gd --check-only
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
- scene failure traces save under `user://artifacts/traces/<suite>/<test>/`
- manual `locator.capture(...)` saves cropped PNGs for visible `Control` targets
- `screen.capture_camera(...)` saves full camera viewport PNGs for `Camera2D` / `Camera3D`
- visual mismatch artifacts save under `user://artifacts/visual_failures/`
- repo baselines live under `res://tests/__snapshots__/`
- JUnit output writes wherever `--junit` points, including `user://...`

## Headless vs Windowed

- Use headless for unit suites, scene logic, and directory runs
- Use windowed when verifying screenshot behavior
- Use windowed for native accessibility-element checks if a test asserts `has_accessibility_element() == true`
- Headless mode should report `screen.can_screenshot() == false`
