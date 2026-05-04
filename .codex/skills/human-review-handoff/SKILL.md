---
name: human-review-handoff
description:
  Move a Symphony issue to Human Review only after validation, PR linkage, and
  feedback sweep requirements are satisfied.
---

# Human Review Handoff

Use this only when implementation is complete or when a true external blocker
requires human action.

## Completion Handoff

Before moving the issue to `Human Review`, verify:

- Workpad plan, acceptance criteria, and validation are up to date.
- Required validation passed on the latest commit, or exact unrelated failures
  are documented.
- Branch is pushed.
- PR is open, linked to the Linear issue, and labeled `symphony`.
- PR body contains a handoff packet with summary, acceptance match, validation,
  risks, artifacts, follow-ups, and blockers.
- Workpad artifact checklist is complete or explicitly marked not applicable.
- Workpad oversight notes either say no approval/sandbox denial occurred or
  explain how the denial was resolved through a safer path.
- PR feedback sweep has no unresolved actionable comments.

Update the `## Codex Workpad` with:

- Commit or branch summary.
- Validation commands and results.
- Proof artifacts collected or why they are not applicable.
- Approval or sandbox denials and safer alternatives attempted.
- Any risks or follow-up issues created.

Then move the Linear issue to `Human Review`.

## Blocker Handoff

Use only for missing required auth, permissions, secrets, or external tools.
Record:

- What is missing.
- Why it blocks the required acceptance/validation.
- Exact human action needed to unblock.
- If applicable, which approval/sandbox denial repeated and why a safer
  alternative was not enough.
