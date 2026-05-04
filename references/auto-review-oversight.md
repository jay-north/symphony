# Auto-Review Oversight Notes

Source: https://alignment.openai.com/auto-review

These notes adapt the auto-review operating model for this Symphony fork. They
are not a claim that model-based review is a security guarantee.

## Useful Findings

- Keep approval review separate from the task-completion agent. The worker is
  optimized to finish the issue; the reviewer should only decide whether a
  boundary-crossing action is acceptable.
- Prefer sandboxed work by default. Review only the small fraction of actions
  that cross boundaries such as network access, writes outside the workspace,
  side-effecting external tools, destructive operations, or secret-adjacent
  reads.
- Denials should be actionable. A denial should include enough rationale for
  the worker to continue safely through a narrower command, read-only check, or
  in-sandbox alternative.
- Stop after repeated denials. Repeated attempts to cross the same boundary can
  indicate policy gaming, unclear scope, or a task that needs a human operator.
- Monitor friction and safety signals: escalation rate, approval rate, denial
  rate, repeated denials, latency, user overrides, and commands frequently
  flagged for review.
- Treat auto-review as one layer. It does not protect against all within-sandbox
  misuse, hidden intent, prompt injection that never reaches a boundary, or
  weaknesses in the broader execution harness.

## Symphony Application

- Repo-local Codex sessions should use `approval_policy = "on-request"`,
  `approvals_reviewer = "auto_review"`, and `sandbox_mode = "workspace-write"`
  unless a task explicitly requires a stricter or more permissive mode.
- Unattended Symphony workers currently receive approval behavior through
  `WORKFLOW.md` and the app-server client. Do not switch them to full access as
  a convenience workaround.
- If a worker hits a denied boundary action, it should record the denial class
  in the workpad, try one safer alternative, and stop for human review after a
  repeat denial.
- Handoff should distinguish between validation failures and oversight denials.
  They imply different next actions.
