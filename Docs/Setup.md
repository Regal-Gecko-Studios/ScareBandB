---
title: Setup
sidebar_position: 2
slug: /setup
---

# Project Setup

Use this flow when bootstrapping a fresh clone or when moving the repo to a new machine.

## Required Tools

- Unreal Engine 5.7
- Git for Windows
- Git LFS
- PowerShell 7+
- Node.js 20+ and npm for the docs site

## First-Run Flow

1. Open PowerShell in the repo root.
2. Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Init-Repo.ps1
```

3. Open `ScareBandB.uproject` and let Unreal regenerate local workspace data if needed.
4. If the repo was moved, verify `ScareBandB.code-workspace` points at the current repo root and local engine install.
5. Start the docs site when you need a local preview:

```powershell
Set-Location website
npm install
docs-tools start
```

The Docusaurus site is already set up in `website/`. You do not need to create a new site scaffold for this repo. See [Docusaurus Setup](./DocsSite/Docusaurus-Setup.md) for the edit/preview/build workflow.

When you are done with the local docs server:

```powershell
docs-tools stop
```

If you want scaffolded docs pages and optional TOC automation in VS Code:

```powershell
docs-tools help
docs-tools install-bridge
```

`docs-tools install-bridge` is optional. It only enables table-of-contents generation for new pages and sections when `Markdown All in One` is also installed in VS Code.

## Engine Discovery Rules

The shared Unreal tooling resolves the engine in this order:

1. The local `.code-workspace` UE folder
2. `UE_ENGINE_DIR`, `UE_ENGINE_ROOT`, or `UNREAL_ENGINE_DIR`
3. Registry lookup from `EngineAssociation`
4. Common UE install roots on this machine

If automated Unreal tooling cannot find the engine, fix one of those sources instead of hardcoding project-specific paths.

## Recommended Variants

- Use `-NoBuild` when you only want hooks, aliases, and repo config without a first build.
- Use `-SkipUnrealSync` when the local engine path is not resolved yet.
- Use `-SkipShellAliases` on CI or any environment where PowerShell profiles should remain untouched.

## Setup Checklist

```text
[ ] git, git-lfs, pwsh, and UnrealEditor.exe are available
[ ] Scripts/Init-Repo.ps1 completed without errors
[ ] core.hooksPath is set to .githooks
[ ] git ours / git theirs / git conflicts aliases are configured
[ ] ue-tools help works in a new PowerShell session
[ ] docs-tools help works in a new PowerShell session
[ ] codex-tools help works in a new PowerShell session
[ ] website/ npm install completed if docs preview is needed
```
