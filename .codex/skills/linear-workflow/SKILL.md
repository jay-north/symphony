---
name: linear-workflow
description:
  Execute a normal Symphony Linear issue from Todo/In Progress through a
  pushed PR and Human Review handoff.
---

# Linear Workflow

Use this skill for normal implementation issues after the dispatcher prompt has
routed the issue to `Todo` or `In Progress`.

## Flow

1. Read the issue by identifier and confirm state, title, description, labels,
   links, and PR attachments.
2. If state is `Todo`, move it to `In Progress` before implementation.
3. Open or create the single `## Codex Workpad` comment.
4. Record environment stamp, plan, acceptance criteria, and validation checklist.
5. Sync with the target branch before edits.
6. Reproduce or confirm the current behavior signal before changing code.
7. Implement the smallest scoped change that satisfies the issue.
8. Run required validation from the issue plus targeted validation for touched
   code.
9. Commit cleanly and push the branch.
10. Open or update a PR, attach it to the Linear issue, and add the `symphony`
    PR label.
11. Run the PR feedback sweep.
12. Use the human-review-handoff skill only when the completion bar is met.

## Guardrails

- Do not expand into unrelated improvements.
- Create Backlog follow-up issues for out-of-scope discoveries.
- Temporary proof edits are allowed only for local validation and must be
  reverted before commit.
- GitHub access is not a blocker until fallback publish/review approaches have
  been attempted and recorded.

