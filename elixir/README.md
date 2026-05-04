# Symphony Elixir

This directory contains the current Elixir/OTP implementation of Symphony, based on
[`SPEC.md`](../SPEC.md) at the repository root.

> [!WARNING]
> Symphony Elixir is prototype software intended for evaluation only and is presented as-is.
> We recommend implementing your own hardened version based on `SPEC.md`.

## Screenshot

![Symphony Elixir screenshot](../.github/media/elixir-screenshot.png)

## How it works

1. Polls Linear for candidate work
2. Creates a workspace per issue
3. Launches Codex in [App Server mode](https://developers.openai.com/codex/app-server/) inside the
   workspace
4. Sends a workflow prompt to Codex
5. Keeps Codex working on the issue until the work is done

During app-server sessions, Symphony also serves a client-side `linear_graphql` tool so that repo
skills can make raw Linear GraphQL calls.

If a claimed issue moves to a terminal state (`Done`, `Closed`, `Cancelled`, or `Duplicate`),
Symphony stops the active agent for that issue and cleans up matching workspaces.

## How to use it

1. Make sure your codebase is set up to work well with agents: see
   [Harness engineering](https://openai.com/index/harness-engineering/).
2. Get a new personal token in Linear via Settings → Security & access → Personal API keys, and
   put it in `elixir/.env` as `LINEAR_API_KEY=...` or export it in your shell.
3. Copy this directory's `WORKFLOW.md` to your repo.
4. Optionally copy the `commit`, `push`, `pull`, `land`, and `linear` skills to your repo.
   - The `linear` skill expects Symphony's `linear_graphql` app-server tool for raw Linear GraphQL
     operations such as comment editing or upload flows.
5. Customize the copied `WORKFLOW.md` file for your project.
   - To get your project's slug, right-click the project and copy its URL. The slug is part of the
     URL.
   - When creating a workflow based on this repo, note that it depends on non-standard Linear
     issue statuses: "Rework", "Human Review", and "Merging". You can customize them in
     Team Settings → Workflow in Linear.
6. Follow the instructions below to install the required runtime dependencies and start the service.

## Prerequisites

We recommend using [mise](https://mise.jdx.dev/) to manage Elixir/Erlang versions.

```bash
mise install
mise exec -- elixir --version
```

## Run

```bash
git clone https://github.com/openai/symphony
cd symphony/elixir
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
mise exec -- ./bin/symphony ./WORKFLOW.md
```

For local auth, copy the example env file once:

```bash
cp .env.example .env
$EDITOR .env
```

`./bin/symphony` automatically loads `.env` from the current directory and from
the directory containing the selected `WORKFLOW.md`. Existing shell environment
variables take precedence over `.env` values.

## Configuration

Pass a custom workflow file path to `./bin/symphony` when starting the service:

```bash
./bin/symphony /path/to/custom/WORKFLOW.md
```

If no path is passed, Symphony defaults to `./WORKFLOW.md`.

Optional flags:

- `--logs-root` tells Symphony to write logs under a different directory (default: `./log`)
- `--port` also starts the Phoenix observability service (default: disabled)

The `WORKFLOW.md` file uses YAML front matter for configuration, plus a Markdown body used as the
Codex session prompt.

Minimal example:

```md
---
tracker:
  kind: linear
  project_slug: "..."
workspace:
  root: ~/code/workspaces
hooks:
  after_create: |
    git clone git@github.com:your-org/your-repo.git .
agent:
  max_concurrent_agents: 2
  max_turns: 6
codex:
  command: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=medium app-server
  command_by_state:
    Rework: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=high app-server
  command_by_label:
    large-refactor: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=high app-server
---

You are working on a Linear issue {{ issue.identifier }}.

Title: {{ issue.title }} Body: {{ issue.description }}
```

Notes:

- If a value is missing, defaults are used.
- Safer Codex defaults are used when policy fields are omitted:
  - `codex.approval_policy` defaults to `{"reject":{"sandbox_approval":true,"rules":true,"mcp_elicitations":true}}`
  - `codex.thread_sandbox` defaults to `workspace-write`
  - `codex.turn_sandbox_policy` defaults to a `workspaceWrite` policy rooted at the current issue workspace
- Supported `codex.approval_policy` values depend on the targeted Codex app-server version. In the current local Codex schema, string values include `untrusted`, `on-failure`, `on-request`, and `never`, and object-form `reject` is also supported.
- Supported `codex.thread_sandbox` values: `read-only`, `workspace-write`, `danger-full-access`.
- When `codex.turn_sandbox_policy` is set explicitly, Symphony passes the map through to Codex
  unchanged. Compatibility then depends on the targeted Codex app-server version rather than local
  Symphony validation.
- `agent.max_turns` caps how many back-to-back Codex turns Symphony will run in a single agent
  invocation when a turn completes normally but the issue is still in an active state. Default: `6`.
- `agent.max_concurrent_agents_by_state` can lower or raise concurrency for specific tracker
  states. This is useful for keeping `Rework` and `Merging` serialized while regular `Todo` issues
  continue normally.
- `codex.command_by_state` and `codex.command_by_label` optionally override `codex.command` for
  specific issue states or labels. Label overrides win over state overrides. Use them for heavier
  reasoning profiles on rework, large refactors, or other intentionally expensive queues.
- For local evaluation, prefer conservative runtime defaults: `agent.max_concurrent_agents: 2`,
  `agent.max_turns: 6`, and `model_reasoning_effort=medium`. Raise these only for intentionally
  larger unattended batches.
- To opt into heavier execution, set a custom workflow file with higher `agent.max_concurrent_agents`,
  higher `agent.max_turns`, or `model_reasoning_effort=xhigh` in `codex.command`.
- If the Markdown body is blank, Symphony uses a default prompt template that includes the issue
  identifier, title, and body.
- Use `hooks.after_create` to bootstrap a fresh workspace. For a Git-backed repo, you can run
  `git clone ... .` there, along with any other setup commands you need.
- If a hook needs `mise exec` inside a freshly cloned workspace, trust the repo config and fetch
  the project dependencies in `hooks.after_create` before invoking `mise` later from other hooks.
- `tracker.api_key` reads from `LINEAR_API_KEY` when unset or when value is `$LINEAR_API_KEY`.
- `./bin/symphony` loads `.env` before reading workflow config. Keep secrets in
  `elixir/.env`; it is ignored by git.
- For path values, `~` is expanded to the home directory.
- For env-backed path values, use `$VAR`. `workspace.root` resolves `$VAR` before path handling,
  while `codex.command` stays a shell command string and any `$VAR` expansion there happens in the
  launched shell.

```yaml
tracker:
  api_key: $LINEAR_API_KEY
workspace:
  root: $SYMPHONY_WORKSPACE_ROOT
hooks:
  after_create: |
    git clone --depth 1 "$SOURCE_REPO_URL" .
codex:
  command: "$CODEX_BIN --config 'model=\"gpt-5.5\"' app-server"
```

- If `WORKFLOW.md` is missing or has invalid YAML at startup, Symphony does not boot.
- If a later reload fails, Symphony keeps running with the last known good workflow and logs the
  reload error until the file is fixed.
- `server.port` or CLI `--port` enables the optional Phoenix LiveView dashboard and JSON API at
  `/`, `/api/v1/state`, `/api/v1/<issue_identifier>`, and `/api/v1/refresh`.
- API running issue payloads include `handoff_readiness.status` with one of `blocked`,
  `validating`, `review_ready`, or `missing_required_artifacts` so operators can see whether a run
  is ready for human review or still missing production handoff evidence.
- API running issue payloads also include `delivery_tracking`, which identifies `single_pr` versus
  `phased` work, current phase when it can be inferred from agent status updates, delivery status,
  and the next route operators should expect.

## Repo-local Codex configuration

This repo keeps durable Codex defaults in `.codex/config.toml` for manual development sessions.
Symphony worker sessions still receive their unattended runtime policy from `WORKFLOW.md`.

## Goal and token strategy

Symphony already owns the orchestration loop: it polls Linear, creates an issue workspace, starts
Codex app-server, sends a workflow prompt, continues turns until the issue leaves an active state or
`agent.max_turns` is reached, and tracks token usage from Codex events.

Codex `/goal` is a persisted thread-goal tool layer inside Codex's model environment. It exposes
goal read/create/complete primitives and system-managed usage accounting for a Codex thread; it is
not a separate issue scheduler or workspace runner. Do not add `/goal` inside Symphony by default.
If Symphony needs budgets, implement them as Symphony-native per-issue runtime state so budget
handoff, issue status, and dashboard/API telemetry stay controlled by the orchestrator.

## Phased PR delivery

Larger issues can be run as a repeatable phase loop instead of one oversized PR:

1. Move a ready issue to `Todo`.
2. Symphony dispatches it because `Todo` is an active tracker state.
3. The agent moves it to `In Progress`, creates or refreshes the single
   `## Codex Workpad`, and decides whether the issue is single-PR or phased.
4. For phased work, the agent writes a `### Phase Plan`, selects one current
   phase, and limits code changes to that phase.
5. The agent opens a phase PR, runs validation and PR feedback sweep, fills the
   PR handoff packet, then moves the issue to `Human Review`.
6. Review feedback moves the issue to `Rework`; an accepted/merged phase can
   move the issue back to `Todo` or `In Progress` for the next unchecked phase.
7. When every phase is checked off, the final accepted handoff can move to the
   terminal workflow state.

Codex `/goal` is useful context for this design: the Linear issue is the
persistent objective, while the workpad phase plan is Symphony's visible,
reviewable lifecycle for completing that objective across multiple agent runs
and PRs.

Token visibility today:

- Terminal dashboard: current session tokens and aggregate totals.
- LiveView dashboard: current input/output/total tokens per issue, aggregate totals, and rate-limit
  snapshot when Codex emits one.
- JSON API: `/api/v1/state` exposes `running[].tokens`, `codex_totals`, and `rate_limits`;
  `/api/v1/<issue_identifier>` exposes the current issue token snapshot.

## Web dashboard

The observability UI now runs on a minimal Phoenix stack:

- LiveView for the dashboard at `/`
- JSON API for operational debugging under `/api/v1/*`
- Bandit as the HTTP server
- Phoenix dependency static assets for the LiveView client bootstrap

## Project Layout

- `lib/`: application code and Mix tasks
- `test/`: ExUnit coverage for runtime behavior
- `WORKFLOW.md`: in-repo workflow contract used by local runs
- `../.codex/`: repository-local Codex skills and setup helpers

## Testing

```bash
make all
```

Run the real external end-to-end test only when you want Symphony to create disposable Linear
resources and launch a real `codex app-server` session:

```bash
cd elixir
export LINEAR_API_KEY=...
make e2e
```

Optional environment variables:

- `SYMPHONY_LIVE_LINEAR_TEAM_KEY` defaults to `SYME2E`
- `SYMPHONY_LIVE_SSH_WORKER_HOSTS` uses those SSH hosts when set, as a comma-separated list

`make e2e` runs two live scenarios:
- one with a local worker
- one with SSH workers

If `SYMPHONY_LIVE_SSH_WORKER_HOSTS` is unset, the SSH scenario uses `docker compose` to start two
disposable SSH workers on `localhost:<port>`. The live test generates a temporary SSH keypair,
mounts the host `~/.codex/auth.json` into each worker, verifies that Symphony can talk to them
over real SSH, then runs the same orchestration flow against those worker addresses. This keeps
the transport representative without depending on long-lived external machines.

Set `SYMPHONY_LIVE_SSH_WORKER_HOSTS` if you want `make e2e` to target real SSH hosts instead.

The live test creates a temporary Linear project and issue, writes a temporary `WORKFLOW.md`, runs
a real agent turn, verifies the workspace side effect, requires Codex to comment on and close the
Linear issue, then marks the project completed so the run remains visible in Linear.

## FAQ

### Why Elixir?

Elixir is built on Erlang/BEAM/OTP, which is great for supervising long-running processes. It has an
active ecosystem of tools and libraries. It also supports hot code reloading without stopping
actively running subagents, which is very useful during development.

### What's the easiest way to set this up for my own codebase?

Launch `codex` in your repo, give it the URL to the Symphony repo, and ask it to set things up for
you.

## License

This project is licensed under the [Apache License 2.0](../LICENSE).
