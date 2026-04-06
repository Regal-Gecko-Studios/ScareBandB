---
title: Target Structure
slug: /project-structure/target-structure
---

# Target Repository Structure (UE 5.7)

This document defines the intended project layout for `ScareBandB` as the game grows beyond bootstrap state.

## Core Rules

- Keep shared gameplay systems in C++ first; use Blueprints for asset assembly, tuning, and thin presentation layers.
- Move Unreal assets in the Unreal Editor only.
- Keep project-authored plugins in `Plugins/Project` and vendor plugins in `Plugins/ThirdParty`.
- Keep editable DCC sources in `ArtSource/`.
- Keep Docusaurus application code in `website/` and source docs in `Docs/`.

## Top-Level Layout

```text
/
|- ScareBandB.uproject
|- Config/
|- Content/
|- Source/
|- Plugins/
|  |- Project/
|  |- ThirdParty/
|- Scripts/
|- Docs/
|- ArtSource/
|- website/
```

## Content Layout

```text
Content/
|- Art/
|  |- Materials/
|  |- Meshes/
|  |  |- House/
|  |  |- Props/
|  |- Textures/
|  |- VFX/
|- Audio/
|- Characters/
|  |- Ghosts/
|  |- Guests/
|- Data/
|  |- Guests/
|  |- Rooms/
|  |- Scares/
|- Gameplay/
|  |- Abilities/
|  |- StateTrees/
|  |- Tags/
|- Input/
|- Maps/
|  |- House/
|  |- Test/
|  |- Dev/
|     |- <UserName>/
|- UI/
|- Developers/
|- __ExternalActors__/
|- __ExternalObjects__/
```

## Source Layout

```text
Source/
|- ScareBandB/
|  |- ScareBandB.Build.cs
|  |- ScareBandB.cpp
|  |- ScareBandB.h
|  |- Public/
|  |  |- AI/
|  |  |- Characters/
|  |  |- Gameplay/
|  |  |- Interaction/
|  |  |- UI/
|  |  |- World/
|  |- Private/
|     |- AI/
|     |- Characters/
|     |- Gameplay/
|     |- Interaction/
|     |- UI/
|     |- World/
|- ScareBandB.Target.cs
|- ScareBandBEditor.Target.cs
```

## Naming Conventions

- Static meshes: `SM_`
- Skeletal meshes: `SK_`
- Materials: `M_`
- Material instances: `MI_`
- Textures: `T_`
- Data assets: `DA_`
- Input actions: `IA_`
- Input mapping contexts: `IMC_`
- Widgets: `WBP_`
- State Trees: `ST_`

Examples:

- `SM_DiningChair_A`
- `DA_GuestFearProfile_Default`
- `IA_GhostManifest`
- `WBP_HauntMeter`

## Map Placement Rules

- Playable house maps: `Content/Maps/House`
- Test and integration maps: `Content/Maps/Test`
- Personal sandboxes: `Content/Maps/Dev/<UserName>`

## Plugin Rules

- Reusable haunt systems or editor tools belong in `Plugins/Project`.
- Marketplace or vendor drops belong in `Plugins/ThirdParty`.
- Keep vendor upgrades isolated from gameplay code changes.

## Worked Example

Goal: add a reusable scare-response framework.

1. Create `Plugins/Project/ScareResponse/`.
2. Add `ScareResponse.uplugin`.
3. Put runtime code under `Source/ScareResponse/`.
4. Keep project-specific glue in `Source/ScareBandB/`.
5. Document any layout rule changes in this file.

## Structure Checklist

```text
[ ] New folders follow the canonical roots above
[ ] Public and Private C++ domains stay mirrored
[ ] Unreal assets were moved in editor, not in Explorer
[ ] Reusable systems were evaluated for plugin placement
[ ] Docs were updated if the target layout changed
```
