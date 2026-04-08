---
title: Coding Standards
slug: /coding-standards
---

# Unreal C++ Coding Standards

This project follows Epic's Unreal C++ coding standard at all times.

Source of truth:

- https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine

## Folder Purpose

`Docs/CodingStandards/` stores local snapshots and team-facing implementation notes for the official standard.

Use this folder so teammates can review the exact coding-standard source used at the time of a change.

## Required Layout

```text
Docs/CodingStandards/
|- README.md
|- Sync-UnrealCppStandard.ps1
|- Parse-UnrealCppStandard.ps1
|- Templates/
|  |- SOURCE.template.md
|- Snapshots/
|  |- YYYY-MM-DD-epic-cpp-standard/
|     |- page.html
|     |- SOURCE.md
|- Generated/
|  |- UnrealCppStandard-Digest.md
```

## Best Way To Bring The Full Web Page Into Repo

Use a raw HTML snapshot from the official Epic page, then keep metadata with it.

Why this is best:

- Captures the full source page, not partial summaries.
- Makes reviews deterministic when the web page changes later.
- Avoids manual copy/paste drift.

## Snapshot Workflow (Exact)

1. Run:
   - `pwsh -File Docs/CodingStandards/Sync-UnrealCppStandard.ps1`
2. This creates:
   - `Docs/CodingStandards/Snapshots/YYYY-MM-DD-epic-cpp-standard/page.html`
3. Copy template:
   - `Docs/CodingStandards/Templates/SOURCE.template.md`
   - to `Docs/CodingStandards/Snapshots/YYYY-MM-DD-epic-cpp-standard/SOURCE.md`
4. Fill all placeholders in `SOURCE.md`.
5. Parse snapshot into digest:
   - `pwsh -File Docs/CodingStandards/Parse-UnrealCppStandard.ps1`
6. Commit snapshot + digest in a docs-only commit.

## Update Frequency

Refresh coding-standard snapshot:

- When upgrading Unreal engine version.
- When Epic updates the coding-standard page.
- At least once per quarter while active development is ongoing.
- At minimum, treat the snapshot as stale once it is older than six months and refresh it before relying on it as the current local reference.

## Codex Usage

- Agents should scrutinize `Docs/CodingStandards/` thoroughly before C++ or style-sensitive work.
- Start with this file, then inspect the latest snapshot folder under `Docs/CodingStandards/Snapshots/`.
- Use `Generated/UnrealCppStandard-Digest.md` as a convenience summary, not as a replacement for the latest snapshot metadata.
- If the latest snapshot is older than six months:
  1. Run `pwsh -File Docs/CodingStandards/Sync-UnrealCppStandard.ps1`
  2. Update or create the matching `SOURCE.md`
  3. Run `pwsh -File Docs/CodingStandards/Parse-UnrealCppStandard.ps1`
  4. Commit the refreshed snapshot and digest in docs scope

## Team Enforcement Checklist

```text
[ ] C++ files follow Unreal naming and style conventions
[ ] New code matches Unreal macro and class patterns
[ ] Snapshot exists for current standard reference date
[ ] SOURCE.md is filled with URL/date/author details
[ ] UnrealCppStandard-Digest.md regenerated from latest snapshot
[ ] Coding standard updates were committed in docs-only scope
```

## Concrete Usage Example

Scenario: teammate introduces new class naming that is questioned in review.

1. Reviewer opens latest snapshot folder under `Docs/CodingStandards/Snapshots/`.
2. Reviewer checks official guidance in `page.html`.
3. Reviewer references snapshot date and source URL from `SOURCE.md`.
4. Team aligns code to standard and merges with traceable rationale.
