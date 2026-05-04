---
name: rework
description:
  Reset and re-execute a Symphony issue after reviewer-requested changes or a
  failed prior approach.
---

# Rework

Treat `Rework` as a full approach reset.

## Flow

1. Re-read the issue body, workpad, PR comments, and human review feedback.
2. Identify what must be done differently from the previous attempt.
3. Close or abandon the prior PR when it cannot be reused cleanly.
4. Start from the current target branch in a fresh branch/workspace if needed.
5. Create a fresh `## Codex Workpad` when the old one reflects the abandoned
   approach.
6. Build a new plan, acceptance criteria, and validation checklist.
7. Execute the normal linear-workflow skill.

Do not patch blindly on top of a rejected approach.
