---
tracker:
  kind: linear
  project_slug: "symphony-0c79b11b75ea"
  active_states:
    - Todo
    - In Progress
    - In Review
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
prompts:
  planner: .symphony/prompts/planner.md
  builder: .symphony/prompts/builder.md
  reviewer: .symphony/prompts/reviewer.md
  rework: .symphony/prompts/rework.md
  land: .symphony/prompts/land.md
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
  max_turns_by_state:
    Todo: 1
    In Progress: 6
    In Review: 3
    Rework: 4
    Merging: 2
  max_concurrent_agents_by_state:
    Todo: 1
    In Review: 1
    Rework: 1
    Merging: 1
codex:
  command: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=medium app-server
  command_by_state:
    In Review: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=high app-server
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

Follow the route-specific prompt selected by Symphony. Keep work inside the issue workspace, maintain one `## Codex Workpad`, use issue-provided validation requirements, and stop only for true blockers.
