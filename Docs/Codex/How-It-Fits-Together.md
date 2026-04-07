---
title: How It Fits Together
slug: /codex-context/how-it-fits-together
---

# How It Fits Together

Codex context in this repo has four practical layers.

## Layer 1: Chat Thread

The current thread is the most immediate working memory. It holds the active task, recent decisions, and any files already read in this conversation.

## Layer 2: Repo Instructions

`AGENTS.md` is the repo-wide routing layer. Keep it short. Its job is to tell Codex which docs and workflows matter first.

## Layer 3: Shared Durable Context

`Docs/Codex/` and the rest of `Docs/` hold the durable shared context that both teammates can review, edit, and version with the code.

## Layer 4: Private Local Context

`.codex-local/` is the repo-local private overlay for one user on one machine. `C:\Users\<user>\.codex\` is the global private layer across all repos.

## Recommended Flow

1. Put stable team knowledge in `Docs/`.
2. Keep `AGENTS.md` short and point it at the right docs.
3. Keep personal preferences and temporary local notes in `.codex-local/`.
4. When a new chat starts, explicitly mention the shared and private files you want used.

## Example

Shared:

- `Docs/Codex/Project-Context.md`
- `Docs/Testing.md`

Private:

- `.codex-local/Private-Context.md`

Opening message:

```text
Read AGENTS.md, Docs/Codex/Project-Context.md, and Docs/Testing.md.
Also use .codex-local/Private-Context.md for my personal preferences.
Then help me diagnose the failing test runner output.
```

## What Not To Rely On

- Old chat threads as a source of truth
- `~/.codex/sessions` as team documentation
- Large project briefs stuffed into `AGENTS.md`
