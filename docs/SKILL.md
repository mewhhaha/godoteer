---
name: docs
description: AI-oriented repo guide for Godoteer, GDScript-first Godot testing harness. Use when changing harness internals, smoke tests, query semantics, accessibility-first APIs, screenshot behavior, or repo docs.
---

# Docs

## Overview

Use this skill when editing Godoteer. Source of truth lives in `sample_project/addons/godoteer/`. Sample scene and smoke suite prove public contract.

## Read Order

- Read [references/repo-map.md](references/repo-map.md) first for layout and runtime flow.
- Read [references/api-surface.md](references/api-surface.md) before touching public harness APIs.
- Read [references/testing-runbook.md](references/testing-runbook.md) before running Godot or debugging failures.
- Read [references/caveats.md](references/caveats.md) before changing queries, screenshots, or failure behavior.

## Core Workflow

1. Build context from repo map and API surface.
2. Change harness code in `sample_project/addons/godoteer/`.
3. Update fixture app and `sample_project/tests/smoke_test.gd` in same pass when public behavior changes.
4. Parse-check modified GDScript.
5. Run headless smoke. Run windowed too when screenshot coverage matters.
6. Update docs in same pass.

## Working Rules

- Keep repo GDScript-first.
- `dev` is source branch. `main` is generated publish branch.
- Preserve suite model: files expose `test_*` methods, each test opens scene with `await driver.screen(...)`.
- Prefer accessibility-first queries: role/name, visible text, label text, placeholder text.
- Treat `get_by_node_name()` as escape hatch only.
- Keep strict cardinality semantics aligned with Testing Library style.
- Keep screenshot guardrails honest: headless mode must not pretend screenshot capture works.
