# ArtSource

`ArtSource/` is the source-of-truth location for editable DCC files and raw art inputs.

`Content/` holds Unreal runtime assets. `ArtSource/` holds authoring sources and export inputs used for reimport.

## Do

- Store editable source files (`.blend`, `.ma`, `.mb`, `.max`, `.c4d`, `.spp`, `.psd`) in `ArtSource/`.
- Keep one asset-set folder with stable naming per asset.
- Export Unreal-import files to that asset folder's `Exports/`.
- Keep one shared template at `ArtSource/_Template` and use it for new art item folders.
- Keep owner and export notes in a shared tracking doc (for example team spreadsheet or task tracker), not per-asset README files.

## Do Not

- Store `.uasset` or `.umap` in `ArtSource/`.
- Commit random scratch files with no asset ownership.
- Use ambiguous export names like `final_final` or `newest`.
- Mix unrelated DCC churn with gameplay code changes.
- Keep per-domain `_Template` folders (`ArtSource/<Domain>/_Template`).

## Shared Template Policy

- Canonical template location: `ArtSource/_Template`.
- New art items should be created by copying `ArtSource/_Template` and renaming to the art item name.
- Use `Scripts/Unreal/New-ArtSourcePath.ps1` to create domains, nested containers, and new art item folders with prompts.

## Standard Asset Folder Pattern

```text
ArtSource/
|- _Template/
|  |- Source/
|  |- Textures/
|  |- Exports/
|- Props/
|  |- Crate_Wood_A/
|     |- Source/ #Source files for programs, Photoshop, Blender, etc...
|     |- Textures/ #Raw Texture files, (.png mostly)
|     |- Exports/ #Naming conventions for LODs: SM_Crate_LOD0.fbx
```

## Concrete Path Examples

Correct examples:

- `ArtSource/Props/Crate_Wood_A/Source/Crate_Wood_A.blend`
- `ArtSource/Props/Crate_Wood_A/Textures/Crate_Wood_A.spp`
- `ArtSource/Props/Crate_Wood_A/Exports/SM_Crate_Wood_A.fbx`

Incorrect examples:

- `ArtSource/Temp/random_test_final_final.blend`
- `ArtSource/Props/Crate_Wood_A/Exports/Copy of mesh.fbx`
- `ArtSource/Props/Crate_Wood_A/Exports/texture_newest.png`

## Naming Rules

- Match Unreal conventions where possible:
  - `SM_<Name>.fbx` - Static Mesh
  - `SK_<Name>.fbx` - Skelital Mesh
  - `T_<Name>_<Usage>.png` - Texture
- Avoid spaces and unclear suffixes in filenames.

Good:

- `SM_Crate_Wood_A.fbx`
- `T_Crate_Wood_A_BC.png`
- `T_Crate_Wood_A_N.png`

Bad:

- `crate final.fbx`
- `texture_newest.png`

## Worked Example Flow: Reexport A Prop Mesh

Goal: update `SM_Crate_Wood_A` mesh and textures.

1. Edit source file: `ArtSource/Props/Crate_Wood_A/Source/Crate_Wood_A.blend`.
2. Rebake/update textures in `ArtSource/Props/Crate_Wood_A/Textures/`.
3. Export to:
   - `ArtSource/Props/Crate_Wood_A/Exports/SM_Crate_Wood_A.fbx`
   - `ArtSource/Props/Crate_Wood_A/Exports/T_Crate_Wood_A_BC.png`
4. Reimport in Unreal target path:
   - `Content/Art/Meshes/Props/House/SM_Crate_Wood_A`
5. Validate material assignment, collision, and LODs in editor.
6. Commit related `ArtSource/` and `Content/` files together with explicit message.

## Art Review Checklist

```text
[ ] Source and export files are inside the correct asset folder
[ ] Export filenames follow Unreal naming conventions
[ ] Owner and export notes are recorded in the team's shared tracker
[ ] Reimport target path in `Content/Art/...` is documented and validated
[ ] No unrelated scratch/temp files were committed
[ ] Commit scope is focused on this asset set
```

## Git/LFS Notes

- Large DCC and export files are LFS-tracked by `.gitattributes`.
- Autosave/temp files are ignored by `.gitignore`.
- Prefer dedicated commits for large art updates.
