# ScareBandB Agent Notes

Scope: this file applies to the entire repository.

## Startup Reads

- On a new chat startup, read the tracked markdown docs in this repo before doing substantial work.
- Prioritize the full `Docs/` tree first.
- Also read area READMEs that describe repo workflows or structure:
  `Scripts/README.md`, `Plugins/README.md`, `ArtSource/README.md`, and `website/README.md`.
- If the task is narrowly scoped and the full doc pass is temporarily disproportionate, still start with:
  `Docs/README.md`, `Docs/Setup.md`, `Docs/Testing.md`, and `Docs/Codex/README.md`,
  then expand to the rest of the docs before producing a substantial patch.

## Coding Standards Check

- Scrutinize `Docs/CodingStandards/` thoroughly before C++ or style-sensitive work.
- Use `Docs/CodingStandards/README.md` as the operating guide for the coding-standards snapshot workflow.
- Use `Docs/CodingStandards/UnrealCppStandard.md` as the readable in-repo coding standard reference.
- Check `Docs/CodingStandards/Current/SOURCE.md` for the current snapshot date.
- If the current coding-standard snapshot is older than six months, rerun:
  `pwsh -File Docs/CodingStandards/Sync-UnrealCppStandard.ps1`
  and then regenerate `Docs/CodingStandards/UnrealCppStandard.md` per `Docs/CodingStandards/README.md` before treating the local standard reference as current.

## Repo Rules

- `Docs/` is the source of truth for team-facing documentation. Keep Docusaurus content in `Docs/`; `website/` only renders it.
- Prefer `Scripts/Tests/Run-AllTests.ps1` as the default automated test entrypoint.
- Some tests mutate branches or require a clean repo. Read `Docs/Testing.md` before running the full suite.
- Avoid editing generated folders unless the task explicitly requires it: `Binaries/`, `DerivedDataCache/`, `Intermediate/`, `Saved/`, `website/.docusaurus/`, `website/build/`, `website/node_modules/`.
- When changing workflow or tooling behavior, update the matching docs in `Docs/` in the same change.
- Always check `.codex-local` for private codex context. Just skip if it doesn't exist.
