---
title: UE Editor Migration
slug: /project-structure/ue-editor-migration
---

# UE Editor Migration Steps

Use this workflow for any move or rename of `.uasset` or `.umap` files.

## Required Rules

- Do the move in Unreal Editor.
- Fix redirectors before finishing the branch.
- Validate the moved assets in the editor before commit.
- Update docs when the canonical content layout changes.

## Standard Flow

1. Sync the branch:

```powershell
git pull --ff-only
git lfs pull
git status --short
```

2. Open the project in Unreal Editor.
3. Move or rename the assets inside the Content Browser.
4. Run `Fix Up Redirectors in Folder` on the moved folder.
5. Open at least one dependent map, Blueprint, or system that references the moved assets.
6. Close the editor and review the file diff.
7. Commit only the intended migration scope.

## Validation Expectations

- Maps using the moved assets still load.
- Data assets still resolve references.
- Any reimport targets from `ArtSource/` still point at the right runtime asset.
- No stray redirectors remain in the moved folders.

## Worked Example

Goal: move guest reaction cues into `Content/Gameplay/Scares`.

1. Create `chore/move-guest-reaction-cues`.
2. Move the cues in Unreal Editor.
3. Fix redirectors in both source and destination folders.
4. Load a guest behavior test map.
5. Run the relevant scare flow in PIE.
6. Commit the asset move and any required doc updates.

## Migration Checklist

```text
[ ] Asset move happened inside Unreal Editor
[ ] Redirectors were fixed up
[ ] Dependent assets/maps were opened and validated
[ ] No generated folders were staged
[ ] Docs updated if the canonical folder policy changed
```
