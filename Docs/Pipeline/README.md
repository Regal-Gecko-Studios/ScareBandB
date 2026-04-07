---
title: Workflow
slug: /workflow
---

# Daily Workflow

This is the required Git and validation workflow for normal project work.

## Branch Naming

- Feature work: `feat/<scope>`
- Fix work: `fix/<scope>`
- Tooling and structure work: `chore/<scope>`

Examples:

- `feat/guest-panic-loop`
- `fix/ghost-possession-reset`
- `chore/docs-docusaurus-bootstrap`

## Start-Of-Day Commands

Run these in order:

```powershell
git pull --ff-only
git lfs pull
git status --short
```

Only start work when the output is clean or intentionally understood.

## Required Practices

- Move `.uasset` and `.umap` files in Unreal Editor, not with filesystem tools.
- Keep docs updates in the same branch as workflow or policy changes.
- Start fresh Codex sessions with `codex-prompt` or `codex-tools prompt` when you want the repo docs and local context called out consistently.
- Use `git ours`, `git theirs`, and `git conflicts` for guarded binary conflict handling.
- Run the relevant script tests before changing hook or automation behavior.
- Preview docs locally in Docusaurus when editing navigation or structure-heavy pages.

## Do Not

- Mix large content migrations with unrelated gameplay work.
- Commit `Saved/`, `Intermediate/`, `DerivedDataCache/`, or `Binaries/`.
- Resolve Unreal binary conflicts by hand-editing files.
- Treat Confluence as the live source of truth for this project.

## Guarded Binary Conflict Flow

1. Inspect current conflict state:

```powershell
git conflicts status
```

2. Resolve the intended side:

```powershell
git ours "Content/**/*.uasset"
git theirs "Content/Maps/**/*.umap"
```

3. Confirm the conflict state again:

```powershell
git conflicts status
```

4. Continue the in-progress operation:

```powershell
git conflicts continue
```

## Worked Example

Goal: move guest reaction assets under a new gameplay folder and document the policy change.

1. Create `chore/guest-reaction-restructure`.
2. Move the assets in Unreal Editor.
3. Fix redirectors in the moved folder.
4. Update [Target Structure](../ProjectStructure/Target-Structure.md) if the canonical layout changed.
5. Run the relevant smoke test in editor.
6. Commit only the moved assets and docs updates.

## PR Checklist

```text
[ ] Branch scope is focused
[ ] Generated folders are not staged
[ ] Asset moves happened in UE Editor
[ ] Relevant docs were updated in the same branch
[ ] Validation steps are written in the PR description
```
