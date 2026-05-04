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
4. If the issue is `Todo`, confirm it has acceptance criteria, a validation/test
   plan, or an explicit exploratory label before moving it to `In Progress`.
5. Decide whether the issue should be single-PR or phased. Use the
   `phased-delivery` skill when the issue is large, risky, explicitly phased,
   or labeled `phased`, `multi-pr`, or `large-refactor`.
6. Record runtime stamp, plan, phase plan if applicable, acceptance criteria,
   validation checklist, and artifact requirements in the workpad.
7. For phased work, select exactly one current phase and limit this run's edits,
   branch, PR, validation, and handoff to that phase.
8. Sync with the target branch before edits.
9. Reproduce or confirm the current behavior signal before changing code.
10. If a command, network, filesystem, or external-tool boundary is denied,
   record the denied action class and rationale in the workpad, try one safer
   in-sandbox or read-only alternative, and stop for human review after a repeat
   denial.
11. Implement the smallest scoped change that satisfies the issue or current
   phase.
12. Run required validation from the issue plus targeted validation for touched
   code.
13. Collect proof artifacts appropriate to the ticket type:
    screenshots/browser checks for UI, request/response or logs for backend/API,
    and preview/render evidence for docs.
14. Commit cleanly and push the branch.
15. Open or update a PR, attach it to the Linear issue, add the `symphony`
    PR label.
16. Fill the PR handoff packet: summary, acceptance match, phase context when
    applicable, validation, risks, artifacts, follow-ups, and blockers.
17. Run the PR feedback sweep.
18. Use the human-review-handoff skill only when the issue or current phase
    handoff bar is met.

## Guardrails

- Do not expand into unrelated improvements.
- Do not implement future phases while completing the current phase PR.
- Create Backlog follow-up issues for out-of-scope discoveries.
- Temporary proof edits are allowed only for local validation and must be
  reverted before commit.
- GitHub access is not a blocker until fallback publish/review approaches have
  been attempted and recorded.
- Do not bury out-of-scope discoveries in handoff notes only; create follow-up
  issues or record why issue creation was blocked.
- Do not weaken sandbox, approval, credential, or network policy to finish an
  ordinary implementation issue.
