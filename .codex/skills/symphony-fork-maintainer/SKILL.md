---
name: symphony-fork-maintainer
description: Maintain this fork of OpenAI Symphony. Use when Codex is asked to evolve Symphony itself, reconcile fork-specific changes with upstream, update repo-local Symphony skills, change WORKFLOW.md or orchestration behavior, prepare maintenance branches, or explain how to build on top of this fork without losing local policy.
---

# Symphony Fork Maintainer

Use this skill before changing the Symphony repo, its repo-local `.codex/skills`,
or the workflow contract that launches agents.

## First Pass

1. Inspect current state:
   - `git status --short`
   - `git remote -v`
   - `git branch --show-current`
2. Treat existing uncommitted changes as user-owned unless the current request
   clearly created them.
3. Read the relevant local contract before edits:
   - `elixir/AGENTS.md` for Elixir coding and validation rules.
   - `elixir/README.md` for runtime setup and documented behavior.
   - `elixir/WORKFLOW.md` for the active agent prompt and workflow config.
   - Existing `.codex/skills/*/SKILL.md` files before editing repo-local skills.
4. If the task involves fork policy, upstream sync, or repo-local skill design,
   read `references/fork-maintenance.md`.

## Maintenance Rules

- Preserve the fork's operating model: `origin` is the writable fork and
  `upstream` is the OpenAI source of truth.
- Keep upstream-compatible changes separated from fork-local policy when
  practical.
- Prefer small, reviewable infrastructure changes over broad cleanup.
- Keep repo-local skills concise and procedural. Put detailed fork policy in
  `references/` when it is not needed for every invocation.
- Do not add auxiliary documentation inside skill folders unless it is a
  direct bundled resource used by the skill.
- When workflow changes affect agent behavior, update `elixir/WORKFLOW.md` and
  the relevant repo-local skill in the same change.
- When runtime/config behavior changes, update `elixir/README.md` and, when the
  behavior changes the implementation contract, `SPEC.md`.

## Validation

Choose the narrowest useful validation first, then widen when the change
touches orchestration, config parsing, or public docs.

```bash
cd elixir
mix specs.check
mix test <targeted-test-file>
make all
```

For repo-local skills, validate the changed skill with the system
`skill-creator` validator:

```bash
python3 /Users/jaynorth/.codex/skills/.system/skill-creator/scripts/quick_validate.py .codex/skills/<skill-name>
```

## Handoff

Report:

- Files changed.
- Validation run and exact result.
- Any existing dirty files that were intentionally left untouched.
