---
name: pr-feedback-sweep
description:
  Collect and resolve actionable PR feedback before a Symphony issue moves to
  Human Review or before landing.
---

# PR Feedback Sweep

Run this whenever a ticket has an attached PR before handoff or merge.

## Required Checks

1. Identify the PR number from issue links, branch, or `gh pr view`.
2. Read top-level PR comments.
3. Read inline review comments.
4. Read review summaries/states.
5. Classify every actionable comment as addressed, deferred with rationale, or
   pushed back with rationale.
6. Apply required code/docs/test fixes.
7. Reply in the correct thread for human review comments when action or pushback
   is needed.
8. Re-run validation after feedback-driven changes.
9. Push updates and refresh PR checks.

## Commands

```bash
gh pr view --comments
gh pr view --json reviews
gh api repos/{owner}/{repo}/pulls/<pr_number>/comments
gh pr checks
```

Completion means there are no unresolved actionable comments and checks are
green or exact unrelated failures are documented.

