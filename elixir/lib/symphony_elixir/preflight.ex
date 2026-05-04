defmodule SymphonyElixir.Preflight do
  @moduledoc """
  Deterministic launch gate for issue readiness and route assignment.
  """

  alias SymphonyElixir.Linear.Issue

  @type route :: :planner | :builder | :reviewer | :rework | :land
  @type decision ::
          {:run, %{route: route(), reason: String.t()}}
          | {:skip, %{reason: atom()}}
          | {:stop, %{reason: atom()}}

  @spec evaluate(Issue.t(), keyword()) :: decision()
  def evaluate(issue, opts \\ [])

  def evaluate(%Issue{} = issue, opts) do
    stop_reason = Keyword.get(opts, :stop_reason)
    active_states = Keyword.get(opts, :active_states, MapSet.new())
    terminal_states = Keyword.get(opts, :terminal_states, MapSet.new())
    running = Keyword.get(opts, :running, %{})
    claimed = Keyword.get(opts, :claimed, MapSet.new())
    slots_available? = Keyword.get(opts, :slots_available?, true)
    state_slots_available? = Keyword.get(opts, :state_slots_available?, true)
    worker_slots_available? = Keyword.get(opts, :worker_slots_available?, true)

    cond do
      is_atom(stop_reason) and not is_nil(stop_reason) ->
        {:stop, %{reason: stop_reason}}

      not valid_issue?(issue) ->
        {:skip, %{reason: :missing_required_issue_fields}}

      not issue.assigned_to_worker ->
        {:skip, %{reason: :not_routed_to_worker}}

      terminal_state?(issue.state, terminal_states) ->
        {:skip, %{reason: :terminal_state}}

      not active_state?(issue.state, active_states) ->
        {:skip, %{reason: :inactive_state}}

      blocked_by_non_terminal?(issue.blocked_by, terminal_states) ->
        {:skip, %{reason: :blocked_by_parent}}

      MapSet.member?(claimed, issue.id) or Map.has_key?(running, issue.id) ->
        {:skip, %{reason: :duplicate_active_run}}

      not slots_available? ->
        {:skip, %{reason: :no_global_capacity}}

      not state_slots_available? ->
        {:skip, %{reason: :no_state_capacity}}

      not worker_slots_available? ->
        {:skip, %{reason: :no_worker_capacity}}

      true ->
        {:run, %{route: route_for_issue(issue), reason: "ready"}}
    end
  end

  def evaluate(_issue, _opts), do: {:skip, %{reason: :invalid_issue}}

  @spec route_for_issue(Issue.t()) :: route()
  def route_for_issue(%Issue{} = issue) do
    issue.labels
    |> Enum.find_value(&route_for_label/1)
    |> case do
      nil -> route_for_state(issue.state)
      route -> route
    end
  end

  defp valid_issue?(%Issue{id: id, identifier: identifier, title: title, state: state})
       when is_binary(id) and is_binary(identifier) and is_binary(title) and is_binary(state),
       do: true

  defp valid_issue?(_issue), do: false

  defp active_state?(state_name, active_states) when is_binary(state_name) do
    MapSet.member?(active_states, normalize_state(state_name))
  end

  defp active_state?(_state_name, _active_states), do: false

  defp terminal_state?(state_name, terminal_states) when is_binary(state_name) do
    MapSet.member?(terminal_states, normalize_state(state_name))
  end

  defp terminal_state?(_state_name, _terminal_states), do: false

  defp blocked_by_non_terminal?(blockers, terminal_states) when is_list(blockers) do
    Enum.any?(blockers, fn
      %{state: blocker_state} when is_binary(blocker_state) ->
        not terminal_state?(blocker_state, terminal_states)

      _ ->
        true
    end)
  end

  defp blocked_by_non_terminal?(_blockers, _terminal_states), do: false

  defp route_for_label(label) when is_binary(label) do
    case normalize_state(label) do
      "planner" -> :planner
      "builder" -> :builder
      "reviewer" -> :reviewer
      "review" -> :reviewer
      "rework" -> :rework
      "land" -> :land
      "lander" -> :land
      _ -> nil
    end
  end

  defp route_for_label(_label), do: nil

  defp route_for_state(state_name) when is_binary(state_name) do
    case normalize_state(state_name) do
      "todo" -> :planner
      "in progress" -> :builder
      "in review" -> :reviewer
      "review" -> :reviewer
      "rework" -> :rework
      "merging" -> :land
      _ -> :builder
    end
  end

  defp route_for_state(_state_name), do: :builder

  defp normalize_state(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
  end
end
