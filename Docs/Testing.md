---
title: Testing
sidebar_position: 4
slug: /testing
---

# Tooling And Workflow Tests

The transferred automation is only useful if it can be revalidated after future repo moves or script changes. Keep this suite green.

## Recommended Order

- `pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/git-hooks/Test-Hooks.ps1`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Tests/Test-UESyncShellAliases.ps1`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Tests/Test-UnrealSync-Regeneration.ps1`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Tests/Test-New-ArtSourcePath.ps1`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Tests/Test-UnrealSync.ps1`
- `pwsh -NoProfile -ExecutionPolicy Bypass -File Scripts/Tests/Test-BinaryGuard-Fixes.ps1`

## What Each Test Covers

- `Test-Hooks.ps1`: validates committed hook plumbing, `core.hooksPath`, git helper aliases, and Git Bash sourcing.
- `Test-UESyncShellAliases.ps1`: validates `ue-tools`, optional `art-tools`, profile bootstrap, and compatibility shims.
- `Test-UnrealSync-Regeneration.ps1`: validates project-file regeneration and engine-resolution fallback paths in isolation.
- `Test-New-ArtSourcePath.ps1`: validates canonical `ArtSource/_Template` handling and new asset folder creation.
- `Test-UnrealSync.ps1`: validates structural trigger detection and hook/non-interactive behavior on a committed clean repo.
- `Test-BinaryGuard-Fixes.ps1`: validates guarded binary conflict helpers across merge and rebase flows.

## Preconditions

- `Test-UnrealSync.ps1` and `Test-BinaryGuard-Fixes.ps1` require a clean repo with at least one commit.
- Tests write logs under `Scripts/Tests/*Results/`.
- Crash-capture scripts are opt-in operational tools, not part of the normal quick suite.

## Crash-Capture Tools

- `Collect-CrashEvidence.ps1`: bundles Unreal logs, crash folders, event logs, and system metadata.
- `Run-CrashCaptureSession.ps1`: launches the editor and arms a post-crash collection flow.

## Manual Validation Helper

Use `Scripts/Tests/Test-Setup-UESync-Manual.ps1` when you want a disposable branch that introduces a structural C++ change to manually exercise the `post-checkout` Unreal sync hook.

## Test Hygiene Checklist

```text
[ ] Result folders stay untracked
[ ] Tests that need a clean repo are not run against a dirty worktree
[ ] Manual Unreal sync validation uses the helper branch script, not ad-hoc file edits
[ ] Any script behavior change updates or adds a matching test
```
