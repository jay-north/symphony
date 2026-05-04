defmodule SymphonyElixirWeb.DashboardLive do
  @moduledoc """
  Live observability dashboard for Symphony.
  """

  use Phoenix.LiveView, layout: {SymphonyElixirWeb.Layouts, :app}

  alias SymphonyElixirWeb.{Endpoint, ObservabilityPubSub, Presenter}
  @runtime_tick_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:payload, load_payload())
      |> assign(:now, DateTime.utc_now())

    if connected?(socket) do
      :ok = ObservabilityPubSub.subscribe()
      schedule_runtime_tick()
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:runtime_tick, socket) do
    schedule_runtime_tick()
    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  @impl true
  def handle_info(:observability_updated, socket) do
    {:noreply,
     socket
     |> assign(:payload, load_payload())
     |> assign(:now, DateTime.utc_now())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="dashboard-shell">
      <header class="hero-card">
        <div class="hero-grid">
          <div>
            <p class="eyebrow">
              Symphony Observability
            </p>
            <h1 class="hero-title">
              What needs attention
            </h1>
            <p class="hero-copy">
              Operations Dashboard for active work, blockers, retries, and the next handoff step.
            </p>
          </div>

          <div class="status-stack">
            <span class="status-badge status-badge-live">
              <span class="status-badge-dot"></span>
              Live
            </span>
            <span class="status-badge status-badge-offline">
              <span class="status-badge-dot"></span>
              Offline
            </span>
          </div>
        </div>
      </header>

      <%= if @payload[:error] do %>
        <section class="error-card">
          <h2 class="error-title">
            Snapshot unavailable
          </h2>
          <p class="error-copy">
            <strong><%= @payload.error.code %>:</strong> <%= @payload.error.message %>
          </p>
        </section>
      <% else %>
        <section class="attention-grid">
          <article class="attention-card">
            <p class="metric-label">Now</p>
            <p class="attention-title"><%= attention_title(@payload) %></p>
            <p class="attention-copy"><%= attention_copy(@payload) %></p>
          </article>

          <article class="metric-card compact-metric">
            <p class="metric-label">Running</p>
            <p class="metric-value numeric"><%= @payload.counts.running %></p>
            <p class="metric-detail">active</p>
          </article>

          <article class="metric-card compact-metric">
            <p class="metric-label">Retrying</p>
            <p class="metric-value numeric"><%= @payload.counts.retrying %></p>
            <p class="metric-detail">backing off</p>
          </article>

          <article class="metric-card compact-metric">
            <p class="metric-label">Tokens</p>
            <p class="metric-value numeric"><%= format_int(@payload.codex_totals.total_tokens) %></p>
            <p class="metric-detail numeric">
              <%= format_runtime_seconds(total_runtime_seconds(@payload, @now)) %> runtime
            </p>
          </article>
        </section>

        <section class="section-card action-section">
          <div class="section-header">
            <div>
              <h2 class="section-title">Active work</h2>
              <p class="section-copy">The thing to inspect when a run is not moving forward.</p>
            </div>
          </div>

          <%= if @payload.running == [] do %>
            <p class="empty-state">No active sessions. Start or pick up a Todo issue.</p>
          <% else %>
            <div class="work-grid">
              <article :for={entry <- @payload.running} class="work-card">
                <div class="work-card-header">
                  <div class="issue-stack">
                    <span class="issue-id"><%= entry.issue_identifier %></span>
                    <span class={state_badge_class(entry.state)}>
                      <%= entry.state %>
                    </span>
                  </div>
                  <a class="primary-link" href={"/api/v1/#{entry.issue_identifier}"}>Open details</a>
                </div>

                <div class="work-main">
                  <p class="work-label">Next action</p>
                  <p class="work-action"><%= next_action(entry) %></p>
                </div>

                <div class="work-facts">
                  <div>
                    <p class="work-label">Delivery</p>
                    <p><%= delivery_label(entry.delivery_tracking) %></p>
                  </div>
                  <div>
                    <p class="work-label">Runtime / turns</p>
                    <p class="numeric"><%= format_runtime_and_turns(entry.started_at, entry.turn_count, @now) %></p>
                  </div>
                  <div>
                    <p class="work-label">Tokens</p>
                    <p class="numeric"><%= format_int(entry.tokens.total_tokens) %></p>
                  </div>
                </div>

                <div class="work-update">
                  <p class="work-label">Latest Codex update</p>
                  <p class="event-text-expanded"><%= entry.last_message || to_string(entry.last_event || "n/a") %></p>
                  <p class="muted event-meta">
                    <%= entry.last_event || "n/a" %>
                    <%= if entry.last_event_at do %>
                      · <span class="mono numeric"><%= entry.last_event_at %></span>
                    <% end %>
                  </p>
                </div>

                <div class="work-actions">
                  <%= if entry.session_id do %>
                    <button
                      type="button"
                      class="subtle-button"
                      data-label="Copy session ID"
                      data-copy={entry.session_id}
                      onclick="navigator.clipboard.writeText(this.dataset.copy); this.textContent = 'Copied'; clearTimeout(this._copyTimer); this._copyTimer = setTimeout(() => { this.textContent = this.dataset.label }, 1200);"
                    >
                      Copy ID
                    </button>
                  <% end %>
                  <%= if entry.workspace_path do %>
                    <button
                      type="button"
                      class="subtle-button"
                      data-label="Copy workspace"
                      data-copy={entry.workspace_path}
                      onclick="navigator.clipboard.writeText(this.dataset.copy); this.textContent = 'Copied'; clearTimeout(this._copyTimer); this._copyTimer = setTimeout(() => { this.textContent = this.dataset.label }, 1200);"
                    >
                      Copy workspace
                    </button>
                  <% end %>
                </div>
              </article>
            </div>
          <% end %>
        </section>

        <section class="metric-grid secondary-metrics">
          <article class="metric-card">
            <p class="metric-label">Running</p>
            <p class="metric-value numeric"><%= @payload.counts.running %></p>
            <p class="metric-detail">Active issue sessions in the current runtime.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Retrying</p>
            <p class="metric-value numeric"><%= @payload.counts.retrying %></p>
            <p class="metric-detail">Issues waiting for the next retry window.</p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Total tokens</p>
            <p class="metric-value numeric"><%= format_int(@payload.codex_totals.total_tokens) %></p>
            <p class="metric-detail numeric">
              In <%= format_int(@payload.codex_totals.input_tokens) %> / Out <%= format_int(@payload.codex_totals.output_tokens) %>
            </p>
          </article>

          <article class="metric-card">
            <p class="metric-label">Runtime</p>
            <p class="metric-value numeric"><%= format_runtime_seconds(total_runtime_seconds(@payload, @now)) %></p>
            <p class="metric-detail">Total Codex runtime across completed and active sessions.</p>
          </article>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Rate limits</h2>
              <p class="section-copy">Latest upstream rate-limit snapshot, when available.</p>
            </div>
          </div>

          <pre class="code-panel"><%= pretty_value(@payload.rate_limits) %></pre>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Running sessions</h2>
              <p class="section-copy">Dense view for comparing active sessions.</p>
            </div>
          </div>

          <%= if @payload.running == [] do %>
            <p class="empty-state">No active sessions.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table data-table-running">
                <colgroup>
                  <col style="width: 12rem;" />
                   <col style="width: 8rem;" />
                   <col style="width: 8.5rem;" />
                   <col style="width: 18rem;" />
                   <col />
                   <col style="width: 10rem;" />
                </colgroup>
                <thead>
                  <tr>
                    <th>Issue</th>
                    <th>State</th>
                     <th>Runtime / turns</th>
                     <th>Next action</th>
                     <th>Codex update</th>
                     <th>Tokens</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @payload.running}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier %></span>
                        <a class="issue-link" href={"/api/v1/#{entry.issue_identifier}"}>JSON details</a>
                      </div>
                    </td>
                    <td>
                      <span class={state_badge_class(entry.state)}>
                        <%= entry.state %>
                      </span>
                    </td>
                     <td class="numeric"><%= format_runtime_and_turns(entry.started_at, entry.turn_count, @now) %></td>
                     <td>
                       <div class="delivery-stack">
                         <span class={delivery_badge_class(entry.delivery_tracking.status)}>
                           <%= delivery_label(entry.delivery_tracking) %>
                         </span>
                         <span class="muted event-meta"><%= next_action(entry) %></span>
                       </div>
                     </td>
                     <td>
                      <div class="detail-stack">
                        <span
                          class="event-text"
                          title={entry.last_message || to_string(entry.last_event || "n/a")}
                        ><%= entry.last_message || to_string(entry.last_event || "n/a") %></span>
                        <span class="muted event-meta">
                          <%= entry.last_event || "n/a" %>
                          <%= if entry.last_event_at do %>
                            · <span class="mono numeric"><%= entry.last_event_at %></span>
                          <% end %>
                        </span>
                      </div>
                    </td>
                    <td>
                      <div class="token-stack numeric">
                        <span>Total: <%= format_int(entry.tokens.total_tokens) %></span>
                        <span class="muted">In <%= format_int(entry.tokens.input_tokens) %> / Out <%= format_int(entry.tokens.output_tokens) %></span>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <section class="section-card">
          <div class="section-header">
            <div>
              <h2 class="section-title">Retry queue</h2>
              <p class="section-copy">Issues waiting for the next retry window.</p>
            </div>
          </div>

          <%= if @payload.retrying == [] do %>
            <p class="empty-state">No issues are currently backing off.</p>
          <% else %>
            <div class="table-wrap">
              <table class="data-table" style="min-width: 680px;">
                <thead>
                  <tr>
                    <th>Issue</th>
                    <th>Attempt</th>
                    <th>Due at</th>
                    <th>Error</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @payload.retrying}>
                    <td>
                      <div class="issue-stack">
                        <span class="issue-id"><%= entry.issue_identifier %></span>
                        <a class="issue-link" href={"/api/v1/#{entry.issue_identifier}"}>JSON details</a>
                      </div>
                    </td>
                    <td><%= entry.attempt %></td>
                    <td class="mono"><%= entry.due_at || "n/a" %></td>
                    <td><%= entry.error || "n/a" %></td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>
      <% end %>
    </section>
    """
  end

  defp load_payload do
    Presenter.state_payload(orchestrator(), snapshot_timeout_ms())
  end

  defp orchestrator do
    Endpoint.config(:orchestrator) || SymphonyElixir.Orchestrator
  end

  defp snapshot_timeout_ms do
    Endpoint.config(:snapshot_timeout_ms) || 15_000
  end

  defp completed_runtime_seconds(payload) do
    payload.codex_totals.seconds_running || 0
  end

  defp total_runtime_seconds(payload, now) do
    completed_runtime_seconds(payload) +
      Enum.reduce(payload.running, 0, fn entry, total ->
        total + runtime_seconds_from_started_at(entry.started_at, now)
      end)
  end

  defp attention_title(%{retrying: retrying}) when retrying != [] do
    "#{length(retrying)} issue(s) backing off"
  end

  defp attention_title(%{running: []}), do: "No active Symphony work"

  defp attention_title(%{running: [entry | _]}) do
    "#{entry.issue_identifier}: #{next_action(entry)}"
  end

  defp attention_copy(%{retrying: [entry | _]}) do
    "Retry #{entry.attempt} is due #{entry.due_at || "soon"}: #{entry.error || "no error recorded"}"
  end

  defp attention_copy(%{running: []}), do: "There is nothing currently moving. Check Todo or start a worker."

  defp attention_copy(%{running: [entry | _]}) do
    update = entry.last_message || to_string(entry.last_event || "no update yet")
    "#{delivery_label(entry.delivery_tracking)} · #{update}"
  end

  defp next_action(%{delivery_tracking: %{current_phase: phase}} = entry) when is_binary(phase) do
    "#{phase}: #{entry.delivery_tracking.next_action}"
  end

  defp next_action(%{delivery_tracking: %{next_action: action}}) when is_binary(action), do: action
  defp next_action(%{handoff_readiness: %{reason: reason}}) when is_binary(reason), do: reason
  defp next_action(_entry), do: "inspect issue details"

  defp format_runtime_and_turns(started_at, turn_count, now) when is_integer(turn_count) and turn_count > 0 do
    "#{format_runtime_seconds(runtime_seconds_from_started_at(started_at, now))} / #{turn_count}"
  end

  defp format_runtime_and_turns(started_at, _turn_count, now),
    do: format_runtime_seconds(runtime_seconds_from_started_at(started_at, now))

  defp format_runtime_seconds(seconds) when is_number(seconds) do
    whole_seconds = max(trunc(seconds), 0)
    mins = div(whole_seconds, 60)
    secs = rem(whole_seconds, 60)
    "#{mins}m #{secs}s"
  end

  defp runtime_seconds_from_started_at(%DateTime{} = started_at, %DateTime{} = now) do
    DateTime.diff(now, started_at, :second)
  end

  defp runtime_seconds_from_started_at(started_at, %DateTime{} = now) when is_binary(started_at) do
    case DateTime.from_iso8601(started_at) do
      {:ok, parsed, _offset} -> runtime_seconds_from_started_at(parsed, now)
      _ -> 0
    end
  end

  defp runtime_seconds_from_started_at(_started_at, _now), do: 0

  defp format_int(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/.{3}(?=.)/, "\\0,")
    |> String.reverse()
  end

  defp format_int(_value), do: "n/a"

  defp state_badge_class(state) do
    base = "state-badge"
    normalized = state |> to_string() |> String.downcase()

    cond do
      String.contains?(normalized, ["progress", "running", "active"]) -> "#{base} state-badge-active"
      String.contains?(normalized, ["blocked", "error", "failed"]) -> "#{base} state-badge-danger"
      String.contains?(normalized, ["todo", "queued", "pending", "retry"]) -> "#{base} state-badge-warning"
      true -> base
    end
  end

  defp delivery_badge_class(status) do
    base = "state-badge delivery-badge"
    normalized = status |> to_string() |> String.downcase()

    cond do
      String.contains?(normalized, ["blocked", "needed"]) -> "#{base} state-badge-danger"
      String.contains?(normalized, ["review", "merging"]) -> "#{base} state-badge-warning"
      String.contains?(normalized, ["executing", "planning", "single", "progress"]) -> "#{base} state-badge-active"
      true -> base
    end
  end

  defp delivery_label(%{mode: "phased", status: status}), do: "Phased · #{humanize_delivery_status(status)}"
  defp delivery_label(%{mode: "single_pr", status: status}), do: "Single PR · #{humanize_delivery_status(status)}"
  defp delivery_label(%{status: status}), do: humanize_delivery_status(status)
  defp delivery_label(_tracking), do: "Unknown"

  defp humanize_delivery_status(status) do
    status
    |> to_string()
    |> String.replace("_", " ")
  end

  defp schedule_runtime_tick do
    Process.send_after(self(), :runtime_tick, @runtime_tick_ms)
  end

  defp pretty_value(nil), do: "n/a"
  defp pretty_value(value), do: inspect(value, pretty: true, limit: :infinity)
end
