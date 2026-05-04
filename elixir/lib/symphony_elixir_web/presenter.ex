defmodule SymphonyElixirWeb.Presenter do
  @moduledoc """
  Shared projections for the observability API and dashboard.
  """

  alias SymphonyElixir.{Config, Orchestrator, StatusDashboard}

  @spec state_payload(GenServer.name(), timeout()) :: map()
  def state_payload(orchestrator, snapshot_timeout_ms) do
    generated_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    case Orchestrator.snapshot(orchestrator, snapshot_timeout_ms) do
      %{} = snapshot ->
        %{
          generated_at: generated_at,
          counts: %{
            running: length(snapshot.running),
            retrying: length(snapshot.retrying)
          },
          running: Enum.map(snapshot.running, &running_entry_payload/1),
          retrying: Enum.map(snapshot.retrying, &retry_entry_payload/1),
          codex_totals: snapshot.codex_totals,
          rate_limits: snapshot.rate_limits
        }

      :timeout ->
        %{generated_at: generated_at, error: %{code: "snapshot_timeout", message: "Snapshot timed out"}}

      :unavailable ->
        %{generated_at: generated_at, error: %{code: "snapshot_unavailable", message: "Snapshot unavailable"}}
    end
  end

  @spec issue_payload(String.t(), GenServer.name(), timeout()) :: {:ok, map()} | {:error, :issue_not_found}
  def issue_payload(issue_identifier, orchestrator, snapshot_timeout_ms) when is_binary(issue_identifier) do
    case Orchestrator.snapshot(orchestrator, snapshot_timeout_ms) do
      %{} = snapshot ->
        running = Enum.find(snapshot.running, &(&1.identifier == issue_identifier))
        retry = Enum.find(snapshot.retrying, &(&1.identifier == issue_identifier))

        if is_nil(running) and is_nil(retry) do
          {:error, :issue_not_found}
        else
          {:ok, issue_payload_body(issue_identifier, running, retry)}
        end

      _ ->
        {:error, :issue_not_found}
    end
  end

  @spec refresh_payload(GenServer.name()) :: {:ok, map()} | {:error, :unavailable}
  def refresh_payload(orchestrator) do
    case Orchestrator.request_refresh(orchestrator) do
      :unavailable ->
        {:error, :unavailable}

      payload ->
        {:ok, Map.update!(payload, :requested_at, &DateTime.to_iso8601/1)}
    end
  end

  defp issue_payload_body(issue_identifier, running, retry) do
    %{
      issue_identifier: issue_identifier,
      issue_id: issue_id_from_entries(running, retry),
      status: issue_status(running, retry),
      workspace: %{
        path: workspace_path(issue_identifier, running, retry),
        host: workspace_host(running, retry)
      },
      attempts: %{
        restart_count: restart_count(retry),
        current_retry_attempt: retry_attempt(retry)
      },
      running: running && running_issue_payload(running),
      retry: retry && retry_issue_payload(retry),
      handoff_readiness: handoff_readiness(running, retry),
      delivery_tracking: delivery_tracking(running, retry),
      logs: %{
        codex_session_logs: []
      },
      recent_events: (running && recent_events_payload(running)) || [],
      last_error: retry && retry.error,
      tracked: %{}
    }
  end

  defp issue_id_from_entries(running, retry),
    do: (running && running.issue_id) || (retry && retry.issue_id)

  defp restart_count(retry), do: max(retry_attempt(retry) - 1, 0)
  defp retry_attempt(nil), do: 0
  defp retry_attempt(retry), do: retry.attempt || 0

  defp issue_status(_running, nil), do: "running"
  defp issue_status(nil, _retry), do: "retrying"
  defp issue_status(_running, _retry), do: "running"

  defp running_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      state: entry.state,
      labels: labels(entry),
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path),
      session_id: entry.session_id,
      turn_count: Map.get(entry, :turn_count, 0),
      last_event: entry.last_codex_event,
      last_message: summarize_message(entry.last_codex_message),
      started_at: iso8601(entry.started_at),
      last_event_at: iso8601(entry.last_codex_timestamp),
      handoff_readiness: handoff_readiness(entry, nil),
      delivery_tracking: delivery_tracking(entry, nil),
      tokens: %{
        input_tokens: entry.codex_input_tokens,
        output_tokens: entry.codex_output_tokens,
        total_tokens: entry.codex_total_tokens
      }
    }
  end

  defp retry_entry_payload(entry) do
    %{
      issue_id: entry.issue_id,
      issue_identifier: entry.identifier,
      attempt: entry.attempt,
      due_at: due_at_iso8601(entry.due_in_ms),
      error: entry.error,
      worker_host: Map.get(entry, :worker_host),
      workspace_path: Map.get(entry, :workspace_path)
    }
  end

  defp running_issue_payload(running) do
    %{
      worker_host: Map.get(running, :worker_host),
      workspace_path: Map.get(running, :workspace_path),
      session_id: running.session_id,
      turn_count: Map.get(running, :turn_count, 0),
      state: running.state,
      labels: labels(running),
      started_at: iso8601(running.started_at),
      last_event: running.last_codex_event,
      last_message: summarize_message(running.last_codex_message),
      last_event_at: iso8601(running.last_codex_timestamp),
      handoff_readiness: handoff_readiness(running, nil),
      delivery_tracking: delivery_tracking(running, nil),
      tokens: %{
        input_tokens: running.codex_input_tokens,
        output_tokens: running.codex_output_tokens,
        total_tokens: running.codex_total_tokens
      }
    }
  end

  defp retry_issue_payload(retry) do
    %{
      attempt: retry.attempt,
      due_at: due_at_iso8601(retry.due_in_ms),
      error: retry.error,
      worker_host: Map.get(retry, :worker_host),
      workspace_path: Map.get(retry, :workspace_path)
    }
  end

  defp workspace_path(issue_identifier, running, retry) do
    (running && Map.get(running, :workspace_path)) ||
      (retry && Map.get(retry, :workspace_path)) ||
      Path.join(Config.settings!().workspace.root, issue_identifier)
  end

  defp workspace_host(running, retry) do
    (running && Map.get(running, :worker_host)) || (retry && Map.get(retry, :worker_host))
  end

  defp recent_events_payload(running) do
    [
      %{
        at: iso8601(running.last_codex_timestamp),
        event: running.last_codex_event,
        message: summarize_message(running.last_codex_message)
      }
    ]
    |> Enum.reject(&is_nil(&1.at))
  end

  defp handoff_readiness(nil, retry) when is_map(retry) do
    %{
      status: "blocked",
      reason: retry.error || "retry scheduled before handoff can continue"
    }
  end

  defp handoff_readiness(running, _retry) when is_map(running) do
    state = running.state |> to_string() |> String.trim() |> String.downcase()

    cond do
      state == "human review" ->
        %{status: "review_ready", reason: "issue is in Human Review"}

      state == "merging" ->
        %{status: "validating", reason: "issue is in Merging flow"}

      blocked_event?(running.last_codex_event) ->
        %{status: "blocked", reason: summarize_message(running.last_codex_message) || "last Codex event requires attention"}

      true ->
        %{
          status: "missing_required_artifacts",
          reason: "handoff packet, validation, artifacts, and feedback sweep are not yet complete"
        }
    end
  end

  defp handoff_readiness(_running, _retry) do
    %{status: "missing_required_artifacts", reason: "issue is not currently running or retrying"}
  end

  defp delivery_tracking(nil, retry) when is_map(retry) do
    %{
      mode: "unknown",
      status: "retrying",
      current_phase: nil,
      next_action: retry.error || "retry scheduled before delivery can continue"
    }
  end

  defp delivery_tracking(running, _retry) when is_map(running) do
    handoff = handoff_readiness(running, nil)
    message = summarize_message(running.last_codex_message) || ""
    current_phase = infer_current_phase(message)

    if phased_delivery?(running, message) do
      phased_delivery_tracking(running, handoff, current_phase)
    else
      %{
        mode: "single_pr",
        status: handoff.status,
        current_phase: nil,
        next_action: handoff.reason
      }
    end
  end

  defp delivery_tracking(_running, _retry) do
    %{
      mode: "unknown",
      status: "idle",
      current_phase: nil,
      next_action: "issue is not currently running or retrying"
    }
  end

  defp phased_delivery_tracking(running, handoff, current_phase) do
    cond do
      handoff.status == "review_ready" ->
        %{
          mode: "phased",
          status: "awaiting_review",
          current_phase: current_phase,
          next_action: "review current phase PR; Rework for changes or Todo/In Progress for next phase"
        }

      handoff.status == "blocked" ->
        %{
          mode: "phased",
          status: "blocked",
          current_phase: current_phase,
          next_action: handoff.reason
        }

      is_nil(current_phase) ->
        %{
          mode: "phased",
          status: "phase_plan_needed",
          current_phase: nil,
          next_action: "create/update Phase Plan and select exactly one current phase"
        }

      true ->
        %{
          mode: "phased",
          status: phase_execution_status(running.state),
          current_phase: current_phase,
          next_action: "complete current phase PR and hand off for review"
        }
    end
  end

  defp phase_execution_status(state) do
    case state |> to_string() |> String.trim() |> String.downcase() do
      "todo" -> "planning"
      "in progress" -> "executing_current_phase"
      "rework" -> "reworking_current_phase"
      "merging" -> "merging_current_phase"
      other when other != "" -> other
      _ -> "executing_current_phase"
    end
  end

  defp phased_delivery?(running, message) do
    labels = labels(running)

    Enum.any?(labels, fn label ->
      normalized = label |> to_string() |> String.trim() |> String.downcase()
      normalized in ["phased", "multi-pr", "large-refactor"]
    end) or String.contains?(String.downcase(message), "phase plan")
  end

  defp infer_current_phase(message) when is_binary(message) do
    case Regex.run(~r/Phase\s+(\d+)\s*\(Current\)\s*:\s*([^\n\r]+)/i, message) do
      [_match, number, title] -> "Phase #{number}: #{String.trim(title)}"
      _ -> nil
    end
  end

  defp infer_current_phase(_message), do: nil

  defp labels(entry) when is_map(entry) do
    entry
    |> Map.get(:labels, [])
    |> case do
      labels when is_list(labels) -> labels
      _ -> []
    end
  end

  defp blocked_event?(event) when is_binary(event) do
    normalized = String.downcase(event)
    String.contains?(normalized, "error") or String.contains?(normalized, "failed")
  end

  defp blocked_event?(_event), do: false

  defp summarize_message(nil), do: nil
  defp summarize_message(message), do: StatusDashboard.humanize_codex_message(message)

  defp due_at_iso8601(due_in_ms) when is_integer(due_in_ms) do
    DateTime.utc_now()
    |> DateTime.add(div(due_in_ms, 1_000), :second)
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp due_at_iso8601(_due_in_ms), do: nil

  defp iso8601(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end

  defp iso8601(_datetime), do: nil
end
