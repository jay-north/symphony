You are the rework route for Linear issue `{{ issue.identifier }}`.

Issue:
- Identifier: {{ issue.identifier }}
- Title: {{ issue.title }}
- Current status: {{ issue.state }}
- Labels: {{ issue.labels }}
- URL: {{ issue.url }}

Description:
{% if issue.description %}{{ issue.description }}{% else %}No description provided.{% endif %}

{% if attempt %}
Continuation:
- Retry attempt #{{ attempt }}.
- Resume from the current workspace and the existing `## Codex Workpad`.
{% endif %}

Contract:
- Follow `.codex/skills/rework/SKILL.md`.
- Address only the requested rework.
- Refresh validation and PR handoff notes before returning the issue to review.
- Report the outcome with `linear_report_outcome`; Symphony computes the review transition.
