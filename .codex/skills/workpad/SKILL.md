---
name: workpad
description:
  Maintain Symphony's single Linear workpad comment for issue progress,
  acceptance criteria, validation, blockers, and handoff notes.
---

# Workpad

Use one persistent Linear comment headed `## Codex Workpad` as the live source
of truth for the run.

## Rules

- Reuse an existing active `## Codex Workpad` comment when present.
- Create exactly one workpad comment when none exists.
- Update the same comment in place; do not post separate progress or done
  comments.
- Keep it compact. Record decisions, current checklist state, validation, and
  blockers.
- Do not edit the Linear issue body for progress tracking.

## Required Format

````md
## Codex Workpad

```text
<hostname>:<abs-path>@<short-sha>
```

### Plan

- [ ] 1. Parent task
- [ ] 2. Parent task

### Acceptance Criteria

- [ ] Criterion 1

### Validation

- [ ] `<command>`

### Notes

- <timestamp> <short factual note>

### Confusions

- <only include when something was confusing during execution>
````

## Update Points

- After initial route/status check.
- After reproduction or first deterministic issue signal.
- After implementation milestones.
- After validation.
- Before PR handoff or blocker handoff.

