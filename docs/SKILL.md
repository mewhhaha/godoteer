---
name: docs
description: Repo guide for Godoteer, GDScript-first Godot testing harness. Use when changing harness internals, public test APIs, runner behavior, smoke fixtures, accessibility-first queries, screenshot or trace behavior, or repo docs.
---

# Docs

Use this skill to navigate Godoteer quickly and keep code, fixtures, tests, and docs aligned.

Source of truth lives in `sample_project/addons/godoteer/`. Sample unit and scene suites prove public contract.

## Read First

- Read [references/repo-map.md](references/repo-map.md) first for layout and runtime flow.
- Read [references/api-surface.md](references/api-surface.md) before changing public harness APIs, queries, actions, or assertions.
- Read [references/testing-runbook.md](references/testing-runbook.md) before running Godot, debugging runner behavior, or validating docs claims about commands.
- Read [references/caveats.md](references/caveats.md) before changing queries, screenshots, traces, accessibility behavior, or failure semantics.

## Workflow

1. Build context from repo map and API surface.
2. Change harness code in `sample_project/addons/godoteer/`.
3. Update fixtures and sample tests in same pass when public behavior changes.
4. Parse-check modified GDScript.
5. Run narrow verification first, then broader headless directory coverage. Run windowed too when screenshot behavior matters.
6. Update README and docs in same pass.

## Rules

- Keep repo GDScript-first.
- `dev` is source branch. `main` is generated publish branch.
- Preserve suite model: files expose `test_*` methods. Unit suites extend `test.gd`. Scene suites extend `test_scene.gd` and open scenes with `await driver.screen(...)`.
- Prefer locator-first actions and waited assertions for scene tests.
- Prefer accessibility-first queries: role/name, visible text, label text, placeholder text.
- Treat `get_by_node_name()` as escape hatch only.
- Keep strict cardinality semantics aligned with Testing Library style.
- Keep screenshot guardrails honest: headless mode must not pretend screenshot capture works.
- Keep runner output, exit codes, and JUnit behavior stable unless change explicitly targets them.
- When public behavior changes, update docs examples to match real supported paths and commands.

## Reference Use

- Use `repo-map.md` for layout and sample coverage.
- Use `api-surface.md` as contract list, not tutorial.
- Use `testing-runbook.md` for runnable commands and verification targets.
- Use `caveats.md` for intentional limits, fallback behavior, and honesty constraints.
