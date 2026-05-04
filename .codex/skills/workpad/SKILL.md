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
codex=<version> model=<model> reasoning=<effort> branch=<branch> state=<issue-state>
```

### Plan

- [ ] 1. Parent task
- [ ] 2. Parent task

### Acceptance Criteria

- [ ] Criterion 1

### Validation

- [ ] `<command>`

### Artifacts

- [ ] <screenshot/browser check, API/log proof, docs preview, or "not applicable: <reason>">

### Notes

- <timestamp> <short factual note>

### Oversight

- <approval/sandbox denial, safer alternative attempted, or "not applicable">

### Confusions

- <only include when something was confusing during execution>
````

## Update Points

- After initial route/status check.
- After runtime/environment stamp collection.
- After reproduction or first deterministic issue signal.
- After implementation milestones.
- After validation.
- After any approval, sandbox, network, or external-tool denial.
- Before PR handoff or blocker handoff.
