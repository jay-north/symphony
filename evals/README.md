# Symphony Skill Evals

This directory contains a lightweight eval harness for repo-local Codex skills.
It follows the OpenAI eval-skills pattern:

1. Run a focused prompt through `codex exec --json`.
2. Save the JSONL trace under `evals/artifacts/`.
3. Score deterministic checks against the trace and final response.
4. Optionally run a structured rubric pass with `--output-schema`.

The default cases are read-only simulations. They are meant to catch skill
triggering and workflow-regression issues without touching Linear, GitHub, or
real Symphony workspaces.

## Run

From the repo root:

```bash
node evals/run-skill-evals.mjs
```

Run a single case:

```bash
node evals/run-skill-evals.mjs --case workpad-01
```

Use another model:

```bash
node evals/run-skill-evals.mjs --model gpt-5.4
```

The runner writes:

- `evals/artifacts/<case-id>.jsonl` - raw `codex exec --json` trace.
- `evals/artifacts/<case-id>.final.txt` - final assistant message.
- `evals/artifacts/results.json` - scored results for the latest run.

## Add Cases

Edit `evals/skill-cases.json`.

Use deterministic checks first:

- `expected_final_substrings` for required final-response evidence.
- `expected_trace_substrings` for required trace evidence.
- `forbidden_trace_substrings` for behavior that must not happen.
- `max_command_executions` to catch thrashing.

For workflow skills, prefer read-only simulation prompts until a case has a
safe isolated repository and fake service credentials.

## Rubric Pass

Use `style-rubric.schema.json` when a deterministic check is too brittle:

```bash
codex exec \
  --cd /Users/jaynorth/dev/tools/symphony \
  --sandbox read-only \
  --output-schema ./evals/style-rubric.schema.json \
  -o ./evals/artifacts/workpad-01.rubric.json \
  "Evaluate evals/artifacts/workpad-01.jsonl against the workpad skill requirements. Return JSON with check ids: skill_triggered, no_real_external_actions, workpad_contract, validation_status."
```

Keep rubric grading secondary. The main regression signal should come from
simple checks that are easy to inspect when they fail.
