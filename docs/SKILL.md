---
name: docs
description: AI-oriented repo guide for Godoteer, a GDScript-first Godot testing harness. Use when working in this repository to understand file layout, run or debug the sample harness, extend the driver/locator/runner, diagnose headless versus windowed behavior, or onboard another agent quickly.
---

# Docs

## Overview

Use this skill to build context before editing Godoteer. Source of truth lives in `sample_project/addons/godoteer_gd/`; sample scene and smoke test double as runnable integration coverage.

## Read Order

- Read [references/repo-map.md](references/repo-map.md) first when you need project layout, ownership, or runtime flow.
- Read [references/testing-runbook.md](references/testing-runbook.md) before running Godot, debugging failures, or checking screenshot behavior.
- Read [references/api-surface.md](references/api-surface.md) before editing `driver.gd`, `locator.gd`, `runner.gd`, or test ergonomics.
- Read [references/caveats.md](references/caveats.md) before changing input composition, query semantics, screenshots, or cleanup behavior.

## Core Workflow

1. Build context from `references/repo-map.md`.
2. Make changes in `sample_project/addons/godoteer_gd/` first; treat sample app and tests as integration fixtures.
3. Run smoke coverage from `references/testing-runbook.md`.
4. If behavior changed, update docs and sample test in same pass.

## Working Rules

- Keep repo GDScript-first. Old JS bridge path was removed.
- Preserve current contract: tests aggregate failures in `GodoteerTestCase`; `runner.gd` converts result to exit code.
- Preserve screenshot guardrails: headless mode should not pretend screenshot capture works.
- Prefer stable queries like `get_by_name()` or `get_by_role()` over text-only queries when text changes during test flow.
- Keep docs high-signal. Put durable repo knowledge here; keep transient observations in commit messages or issues.

## References

- [references/repo-map.md](references/repo-map.md)
- [references/testing-runbook.md](references/testing-runbook.md)
- [references/api-surface.md](references/api-surface.md)
- [references/caveats.md](references/caveats.md)
