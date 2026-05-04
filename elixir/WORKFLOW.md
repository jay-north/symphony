---
tracker:
  kind: linear
  project_slug: "symphony-0c79b11b75ea"
  active_states:
    - Todo
    - In Progress
    - Merging
    - Rework
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done
polling:
  interval_ms: 5000
workspace:
  root: ~/code/symphony-workspaces
hooks:
  after_create: |
    git clone --depth 1 https://github.com/openai/symphony .
    if command -v mise >/dev/null 2>&1; then
      cd elixir && mise trust && mise exec -- mix deps.get
    fi
  before_remove: |
    cd elixir && mise exec -- mix workspace.before_remove
agent:
  max_concurrent_agents: 2
  max_turns: 6
  max_concurrent_agents_by_state:
    Rework: 1
    Merging: 1
codex:
  command: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=medium app-server
  command_by_state:
    Rework: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=high app-server
  command_by_label:
    large-refactor: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=high app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
---

You are working on Linear issue `{{ issue.identifier }}`.

Issue:
- Identifier: {{ issue.identifier }}
- Title: {{ issue.title }}
- Current status: {{ issue.state }}
- Labels: {{ issue.labels }}
- URL: {{ issue.url }}

Description:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

{% if attempt %}
Continuation:
- Retry attempt #{{ attempt }}.
- Resume from the current workspace and the existing `## Codex Workpad`.
- Do not repeat completed investigation unless the current workspace state requires it.
{% endif %}

Operating rules:
- Work only inside the provided workspace.
- Do not ask the human for routine follow-up actions.
- Stop only for true blockers: missing required auth, permissions, secrets, or a scope conflict that cannot be resolved in this workspace.
- Maintain exactly one Linear comment headed `## Codex Workpad`; update it in place as the plan, acceptance criteria, validation, and notes change.
- Keep the workpad concise. Prefer changed facts, completed checklist items, validation results, blockers, and handoff notes.
- Use issue-provided `Validation`, `Test Plan`, or `Testing` sections as required acceptance input.
- File out-of-scope discoveries as separate Backlog issues instead of expanding this issue.
- Before moving a `Todo` issue to `In Progress`, confirm it has acceptance criteria, a validation/test plan, or an explicit exploratory label. If it does not, create/update the workpad with the missing readiness item and stop without coding.
- Before implementation, decide whether this issue is single-PR or phased. Use phased delivery when the issue is large, risky, explicitly phased, or labeled `phased`, `multi-pr`, or `large-refactor`.
- For phased delivery, treat the issue as the persistent objective, maintain `### Phase Plan` in the workpad, select exactly one current phase, ship one PR for that phase, hand off for review, and repeat on the next `Todo`/`In Progress` run.
- Stamp the workpad with hostname, absolute workspace path, short SHA, Codex version, model, reasoning effort, branch, and issue state before implementation.
- For UI work, include screenshots or browser verification artifacts in the handoff. For backend/API work, include request/response or log proof. For docs work, include preview or render proof when available.
- Treat sandbox or approval denials as oversight signals, not routine blockers to brute-force. Record the denied action class and rationale in the workpad, try one narrower in-sandbox or read-only alternative, and stop for human review after a repeat denial.
- Do not weaken sandbox, approval, credential, or network policy to finish a ticket unless the issue explicitly asks for an oversight-policy change.

Route by status:
- `Backlog`: do not modify; stop.
- `Todo`: move to `In Progress`, create or refresh `## Codex Workpad`, then execute.
- `In Progress`: continue from the existing workpad and workspace state.
- `Human Review`: do not code; wait for review updates.
- `Rework`: follow `.codex/skills/rework/SKILL.md`.
- `Merging`: follow `.codex/skills/land/SKILL.md`; do not call `gh pr merge` directly outside that flow.
- Terminal states (`Done`, `Closed`, `Cancelled`, `Canceled`, `Duplicate`): do nothing.

Load detailed procedures only when needed:
- Linear issue/comment operations: `.codex/skills/linear/SKILL.md`
- Workpad format and update rules: `.codex/skills/workpad/SKILL.md`
- Normal implementation and PR handoff: `.codex/skills/linear-workflow/SKILL.md`
- Phased multi-PR delivery: `.codex/skills/phased-delivery/SKILL.md`
- Maintaining this Symphony fork or repo-local skills: `.codex/skills/symphony-fork-maintainer/SKILL.md`
- Auto-review oversight notes: `references/auto-review-oversight.md`
- PR feedback sweep: `.codex/skills/pr-feedback-sweep/SKILL.md`
- Human review handoff: `.codex/skills/human-review-handoff/SKILL.md`
- Rework reset: `.codex/skills/rework/SKILL.md`
- Landing/merge: `.codex/skills/land/SKILL.md`

Hard completion bar before moving to `Human Review`:
- Workpad plan, acceptance criteria, and validation are current and checked off.
- For phased delivery, current phase acceptance is checked off and later phases remain out of scope for this PR.
- Required validation passes on the latest commit, or the exact unrelated blocker is documented.
- PR body contains a handoff packet with summary, acceptance match, phase context when applicable, validation, risks, artifacts, follow-ups, and blockers.
- Branch is pushed, PR is linked on the issue, and the PR is labeled `symphony`.
- Any approval or sandbox denial was resolved through a safer path or documented as an operator blocker.
- PR feedback sweep finds no unresolved actionable comments.
- Final response reports completed actions and blockers only; do not include generic next steps for the user.
