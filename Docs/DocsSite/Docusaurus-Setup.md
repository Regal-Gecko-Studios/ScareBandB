---
title: Docusaurus Setup
slug: /docs-site/setup
---

# Docusaurus Setup

This project publishes repo docs through Docusaurus.

## Source Of Truth

- Source markdown: `Docs/`
- Docusaurus app: `website/`

Do not author long-form project docs in `website/docs`. That scaffold is intentionally unused here.

## Local Commands

```powershell
Set-Location website
npm install
npm start
```

Production build:

```powershell
Set-Location website
npm run build
npm run serve
```

## Current Wiring

- The Docusaurus docs plugin reads from `../Docs`.
- Blog output is disabled.
- Coding-standard `Snapshots/` and `Templates/` are excluded from the site build.
- Navigation is defined in `website/sidebars.ts`.

## Deployment Notes

- Update `website/docusaurus.config.ts` `url` and repository metadata before a real deployment target is chosen.
- Keep docs deployment separate from gameplay feature branches when possible.
- Validate `npm run build` before merging navigation changes.

## When To Update The Site App

- Adding a new top-level docs section
- Changing global navigation
- Adjusting theme, branding, or footer content
- Changing deploy metadata or base URL
