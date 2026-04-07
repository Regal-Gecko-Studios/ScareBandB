---
title: Docusaurus Setup
slug: /docs-site/setup
---

# Docusaurus Setup

This project publishes repo docs through Docusaurus.

You do not need to scaffold a new Docusaurus site for this repo. The site already exists in `website/` and is wired to render the markdown in `Docs/`.

## Source Of Truth

- Source markdown: `Docs/`
- Docusaurus app: `website/`

Do not author long-form project docs in `website/docs`. That scaffold is intentionally unused here.

## One-Time Local Setup

1. Make sure Node.js 20+ and npm are installed.
2. Open PowerShell in the repo root.
3. Run:

```powershell
Set-Location website
npm install
```

That installs the Docusaurus app dependencies only. Your actual docs still live in `../Docs`.

## Daily Preview Workflow

Run:

```powershell
Set-Location website
npm start
```

Then open:

```text
http://localhost:3000/docs/
```

What happens next:

- Docusaurus starts a local dev server.
- Editing files in `Docs/` updates the site preview.
- The terminal stays attached until you stop it with `Ctrl+C`.

## What To Edit

- Edit page content in `Docs/`.
- Add or reorder major navigation groups in `website/sidebars.ts`.
- Change site-wide branding, footer, navbar, or deploy metadata in `website/docusaurus.config.ts`.

## Production Build Check

Use this before merging docs-navigation changes or site-config changes:

```powershell
Set-Location website
npm run build
npm run serve
```

`npm run build` validates the docs as a production site. `npm run serve` lets you inspect the generated static build locally.

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

## Common Mistakes

- Do not write the real project docs under `website/docs`.
- Do not edit `website/.docusaurus/`, `website/build/`, or `website/node_modules/`.
- If a new doc page exists but does not show in navigation, update `website/sidebars.ts`.
- If the build fails on links, fix the markdown links in `Docs/` rather than weakening the Docusaurus checks.
