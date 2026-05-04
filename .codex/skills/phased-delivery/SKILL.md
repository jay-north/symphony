---
name: phased-delivery
description:
  Plan a larger Symphony issue into reviewable phases, execute one phase per PR,
  hand off for review, then repeat until the phase plan is complete.
---

# Phased Delivery

Use this skill when an issue is large, risky, explicitly asks for phases, has a
`phased`, `large-refactor`, or `multi-pr` label, or cannot be reviewed well as
one PR.

## Phase Contract

1. Treat the Linear issue as the persistent objective.
2. Create or refresh the `### Phase Plan` section in the single
   `## Codex Workpad`.
3. Split the objective into small, reviewable phases that can each land as one
   PR.
4. Mark exactly one phase as `Current`.
5. Include the exact marker `Phase N (Current): <goal>` in workpad updates,
   PR handoff notes, and final/status messages so Symphony's interface can
   infer and display the current phase.
6. Execute only the current phase unless the issue explicitly says one PR should
   cover multiple phases.
7. Keep later phases as pending work; do not opportunistically implement them.
8. After the current phase is pushed, open or update one PR for that phase.
9. Put the phase number and phase goal in the PR title/body.
10. Run the PR feedback sweep for that phase.
11. Move to `In Review` after the phase handoff bar is met.

## Workpad Phase Plan

Use this compact format:

```md
### Phase Plan

- [ ] Phase 1 (Current): <reviewable outcome>
- [ ] Phase 2: <reviewable outcome>
- [ ] Phase 3: <reviewable outcome>

Current phase acceptance:
- [ ] <phase-specific criterion>

Next after review:
- If PR is accepted and merged, return the issue to `Todo` or `In Progress` for
  the next unchecked phase.
- If review requests changes, move the issue to `Rework` and keep the same
  current phase.
```

## PR Requirements

- Title starts with `Phase N:`.
- Body includes the phase goal, current phase acceptance match, validation,
  artifacts, risks, and remaining phases.
- Scope is limited to the current phase.
- Follow-up work is captured as remaining phases or new Backlog issues.

## Repeat Rules

- On `Rework`, fix the current phase PR; do not advance phases.
- On the next `Todo`/`In Progress` run after a merged phase, mark the completed
  phase checked, select the next unchecked phase, and repeat.
- When all phases are checked and the final PR is accepted, the issue can move
  to the terminal workflow state.
