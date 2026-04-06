---
title: Authoring Docs
slug: /docs-site/authoring
---

# Authoring Docs

Write docs in `Docs/`. Keep the site shell in `website/` thin.

## Authoring Rules

- Prefer concrete examples tied to this repo.
- Put commands in fenced code blocks.
- Use repository-relative paths.
- Add front matter when a page needs a stable slug or custom title.
- Update `website/sidebars.ts` when a new major section should appear in navigation.

## Content Rules

- Replace stale process docs instead of layering contradictory notes on top.
- Keep Confluence references clearly marked as legacy context only.
- Avoid TODO-only pages. Either write the policy or do not create the page yet.
- Keep operational runbooks close to the scripts they describe.

## Linking Guidance

- Link sibling docs with relative markdown links inside `Docs/`.
- Link repo files with explicit repo-relative paths when giving commands or examples.
- Prefer stable section headings over loose “see above” references.

## Review Checklist

```text
[ ] Title and slug still fit the navigation structure
[ ] Links resolve in local Docusaurus preview
[ ] Commands were tested or marked manual
[ ] Repo paths match the current structure
[ ] Page content supersedes any old Confluence guidance
```
