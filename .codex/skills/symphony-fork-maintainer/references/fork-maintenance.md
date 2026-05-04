# Fork Maintenance Reference

## Repository Model

- This checkout is a fork of `openai/symphony`.
- Keep `origin` as the writable fork remote.
- Keep `upstream` as the read-only source remote; do not change its push target.
- Before any upstream reconciliation, inspect local changes and branch state.

## Upstream Sync Flow

Use this only when the user asks to sync, rebase, merge, or compare against
upstream.

```bash
git status --short
git remote -v
git fetch upstream
git log --oneline --decorate --graph --left-right HEAD...upstream/main --max-count=40
git diff --stat HEAD..upstream/main
```

Choose a merge or rebase based on the user's requested history policy. If no
policy is given, prefer an explicit merge for shared branches and ask before
rewriting any pushed branch.

## Change Classification

Classify changes before editing:

- Upstream-compatible implementation: fixes or improvements that could be sent
  back to `openai/symphony`.
- Fork-local policy: workflow statuses, local skills, project-specific prompts,
  model settings, dashboard defaults, or user-specific operating conventions.
- Generated evidence: snapshots, coverage output, logs, or fixtures. Update
  only when directly caused by the code or test behavior under change.

Keep these categories separate in commits and PR descriptions when practical.

## Repo-Local Skills

Repo-local skills live in `.codex/skills/` at the repository root. They are part
of the Symphony operating layer and should stay usable by agents launched inside
issue workspaces.

When adding or updating a skill:

1. Use `skill-creator` conventions.
2. Keep frontmatter to `name` and `description`.
3. Put triggering detail in `description`, because only frontmatter is always
   visible before the skill body loads.
4. Keep `SKILL.md` procedural and concise.
5. Put long policy or examples in one-level `references/` files.
6. Validate with `quick_validate.py`.
7. If `elixir/WORKFLOW.md` routes agents to the skill, update that route in the
   same change.

## Symphony-Specific Checks

- Workflow config and prompt changes should account for strict template
  rendering.
- Workspace changes must preserve path safety and must not run Codex turns in
  the source repo.
- Orchestrator changes should preserve polling, retry, reconciliation,
  terminal-state cleanup, and token accounting semantics.
- Config additions should flow through `SymphonyElixir.Config` rather than
  ad-hoc environment reads.
