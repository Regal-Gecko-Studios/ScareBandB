# Plugin Conventions

This folder separates team-owned plugins from vendor-provided plugins.

## Canonical Layout

```text
Plugins/
|- Project/     # Team-owned plugins
|- ThirdParty/  # Vendor or external plugins
```

Concrete example:

```text
Plugins/
|- Project/
|  |- CozyInventory/
|  |  |- CozyInventory.uplugin
|  |  |- Source/
|  |  |- Config/
|  |  |- Resources/
|- ThirdParty/
|  |- FMODStudio/
|     |- FMODStudio.uplugin
|     |- Source/
|     |- Binaries/
```

## Do

- Place team-authored plugins in `Plugins/Project/<PluginName>/`.
- Place vendor plugins in `Plugins/ThirdParty/<PluginName>/`.
- Keep plugin name aligned with `.uplugin` filename.
- Isolate vendor upgrades in dedicated commits/PRs.
- Document local vendor patches with exact file list and reason.

## Do Not

- Mix vendor upgrades with gameplay feature commits.
- Place team plugins in `ThirdParty`.
- Hide local vendor edits without documentation.
- Create a plugin when feature is tightly coupled and non-reusable.

## When A Plugin Is Appropriate

Create a plugin when functionality is reusable, optional, or needs isolation from core module code.

Plugin examples:

- Shared inventory framework reused by multiple game modes.
- Editor-only asset validation tools.

Keep in `Source/ScareBandB` examples:

- One-off gameplay ability unique to this project.
- Small runtime component tightly bound to one game mode.

## Concrete Path Examples

Correct:

- `Plugins/Project/CozyInventory/Source/CozyInventory/Private/InventorySubsystem.cpp`
- `Plugins/ThirdParty/FMODStudio/FMODStudio.uplugin`

Incorrect:

- `Plugins/FMODStudio/FMODStudio.uplugin`
- `Plugins/ThirdParty/CozyInventory/CozyInventory.uplugin`

## Worked Example Flow: Add A Team Plugin

Goal: add reusable house-systems plugin.

1. Create folder `Plugins/Project/ScareHouseSystems/`.
2. Add `ScareHouseSystems.uplugin` and plugin internals:
   - `Source/`
   - `Config/`
   - `Resources/`
3. Add runtime code, for example:
   - `Plugins/Project/ScareHouseSystems/Source/ScareHouseSystems/Public/HauntSubsystem.h`
   - `Plugins/Project/ScareHouseSystems/Source/ScareHouseSystems/Private/HauntSubsystem.cpp`
4. Build project and confirm editor startup succeeds.
5. Commit with explicit message:
   - `Add ScareHouseSystems project plugin scaffold`
6. Update docs if plugin policy or workflow changed.
