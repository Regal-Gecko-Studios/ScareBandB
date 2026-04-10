---
title: Workflow
slug: /workflow
---

# Daily Workflow

This is the required day-to-day workflow for normal project work.

Git-specific repo standards now live in one place:

- [Git Workflow Standards](./Git-Branch-And-PR-Workflow.md)

Use that page for:

- branch naming
- rebasing and branch cleanup before review
- PR and merge policy
- guarded conflict handling

## Required Practices

- Move `.uasset` and `.umap` files in Unreal Editor, not with filesystem tools.
- Start fresh Codex sessions with `codex-prompt` or `codex-tools prompt` when you want the repo docs and local context called out consistently.
- Run the relevant script tests before changing hook or automation behavior.
- Use `docs-tools new-section` and `docs-tools new-page` for routine docs scaffolding.
- Use `docs-tools reorder` instead of hand-editing multiple sibling positions when docs nav order changes.
- Run `docs-tools check` before merging docs-structure or docs-site workflow changes.
- Preview docs locally when editing navigation or structure-heavy pages with `docs-tools start`, or `docs-tools start --background` when you want detached tracked mode.

## Do Not

- Mix large content migrations with unrelated gameplay work.
- Treat Confluence as the live source of truth for this project.

## Worked Example

Goal: move guest reaction assets under a new gameplay folder and document the policy change.

1. Create a correctly named branch using [Git Workflow Standards](./Git-Branch-And-PR-Workflow.md).
2. Move the assets in Unreal Editor.
3. Fix redirectors in the moved folder.
4. Update [Target Structure](../ProjectStructure/Target-Structure.md) if the canonical layout changed.
5. Run the relevant smoke test in editor.
6. Commit only the moved assets and docs updates.
