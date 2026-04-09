---
title: Project Context
slug: /codex-context/project-context
---

# Shared Project Context

This file is the short, stable Codex-facing brief for `ScareBandB`.

## Project Summary

- `ScareBandB` is a UE 5.7 multiplayer project where up to four players play as ghosts trying to scare guests out of a rented house.
- `Docs/` is the source of truth for team-facing project docs.
- `website/` renders the docs with Docusaurus; it is not the primary authoring location.

## Important Roots

- `Source/`: game code
- `Scripts/`: repo tooling, Unreal helpers, and tests
- `Docs/`: shared docs and process guidance
- `Plugins/`: project and third-party plugin roots
- `ArtSource/`: DCC source files and import staging

## Working Rules

- Update docs in the same branch as behavior changes.
- Prefer `Scripts/Tests/Run-AllTests.ps1` as the default automated test entrypoint.
- Some tests mutate branches or require a clean repo. Read `Docs/Testing.md` before running the full suite.
- Keep Docusaurus content in `Docs/`; `website/` should stay thin.
- Treat Confluence as retired for this project.

## Good First Reads For Codex

- `AGENTS.md`
- `Docs/README.md`
- `Docs/Setup.md`
- `Docs/Testing.md`

## Example Task Starter

```text
Use Docs/Codex/Project-Context.md as the shared project brief.
Read Docs/Testing.md before changing Scripts/Tests.
Help me add a new Unreal tooling test.
```
