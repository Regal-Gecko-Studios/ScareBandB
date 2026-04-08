---
title: Overview
sidebar_position: 1
slug: /
---

# ScareBandB Documentation

`Docs/` is the source of truth for team-facing project documentation.

`ScareBandB` is a UE 5.7 multiplayer project where up to four players act as ghosts trying to scare guests out of a rented house. Repo workflow, tooling, structure, and testing rules live here with the code.

## Documentation Contract

- Update docs in the same branch as behavior changes.
- Use repository paths and real commands, not abstract placeholders.
- Keep Docusaurus content in `Docs/`; `website/` only renders it.
- Treat Confluence as retired for this project. New process and design docs belong in this repo.

## Read Order

1. [Setup](./Setup.md)
2. [Game Design](./GameDesign/README.md)
3. [Target Structure](./ProjectStructure/Target-Structure.md)
4. [Workflow](./Pipeline/README.md)
5. [Testing](./Testing.md)
6. [Coding Standards](./CodingStandards/README.md)
7. [Docusaurus Setup](./DocsSite/Docusaurus-Setup.md)
8. [Codex Context](./Codex/README.md)

## High-Level Ownership

- `Docs/`: source markdown and process docs
- `AGENTS.md`: short repo-wide Codex routing instructions
- `website/`: Docusaurus app used to preview and publish `Docs/`
- `Scripts/`: automation, hooks, Unreal helpers, and test harnesses
- `Plugins/`: project and third-party plugin roots
- `ArtSource/`: DCC source files and import staging

## Quality Checklist

```text
[ ] Docs changed in the same branch as the behavior change
[ ] Commands were validated or clearly marked as manual
[ ] Paths are repo-relative and copy-pasteable
[ ] Confluence references were removed or explicitly marked as legacy
[ ] Docusaurus navigation still matches the Docs/ tree
```
