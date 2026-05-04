defmodule SymphonyElixir.StateTransition do
  @moduledoc """
  Computes tracker state transitions from route-specific agent outcomes.
  """

  alias SymphonyElixir.Outcome

  @type route :: :planner | :builder | :reviewer | :rework | :land | String.t() | nil
  @type decision ::
          {:transition, String.t(), String.t()}
          | {:stay, String.t()}
          | {:blocked, String.t()}

  @spec decide(route(), Outcome.t()) :: decision()
  def decide(route, %Outcome{} = outcome) do
    case normalize_route(route) do
      :planner -> planner_decision(outcome)
      :builder -> builder_decision(outcome)
      :reviewer -> reviewer_decision(outcome)
      :rework -> rework_decision(outcome)
      :land -> land_decision(outcome)
      _ -> {:stay, "no route-specific transition rule"}
    end
  end

  defp planner_decision(%Outcome{status: status}) do
    case normalize_status(status) do
      "ready" -> {:transition, "In Progress", "planner reported ready"}
      "missing_acceptance_criteria" -> {:transition, "Backlog", "planner reported missing acceptance criteria"}
      "missing_validation" -> {:transition, "Backlog", "planner reported missing validation"}
      "blocked" -> {:transition, "Backlog", "planner reported blocker"}
      _ -> {:stay, "planner outcome did not request a transition"}
    end
  end

  defp builder_decision(%Outcome{} = outcome) do
    cond do
      normalize_status(outcome.status) in ["missing_acceptance_criteria", "missing_validation", "blocked"] ->
        {:transition, "Backlog", "builder reported issue is not runnable"}

      normalize_status(outcome.status) in ["ready_for_review", "completed"] and
        validation_passed?(outcome.validation) and has_pr?(outcome) ->
        {:transition, "In Review", "builder completed PR with validation"}

      normalize_status(outcome.status) in ["ready_for_review", "completed"] ->
        {:blocked, "builder completion is missing a PR URL or passing validation"}

      true ->
        {:stay, "builder outcome did not meet transition requirements"}
    end
  end

  defp reviewer_decision(%Outcome{} = outcome) do
    cond do
      outcome.unresolved_comments ->
        {:transition, "Rework", "reviewer found unresolved comments"}

      normalize_status(outcome.status) in ["accepted", "checks_passed", "ready_to_merge"] ->
        {:transition, "Merging", "reviewer accepted PR"}

      true ->
        {:stay, "reviewer outcome did not meet merge requirements"}
    end
  end

  defp rework_decision(%Outcome{} = outcome) do
    if normalize_status(outcome.status) in ["ready_for_review", "completed"] and validation_passed?(outcome.validation) do
      {:transition, "In Review", "rework completed with validation"}
    else
      {:stay, "rework outcome did not meet review requirements"}
    end
  end

  defp land_decision(%Outcome{} = outcome) do
    if outcome.merged == true or normalize_status(outcome.status) == "merged" do
      {:transition, "Done", "land route reported merged PR"}
    else
      {:stay, "land outcome is not merged"}
    end
  end

  defp validation_passed?(validation) when is_binary(validation) do
    normalize_status(validation) in ["passed", "pass", "green"]
  end

  defp validation_passed?(_validation), do: false

  defp has_pr?(%Outcome{pr_url: pr_url}) when is_binary(pr_url), do: String.trim(pr_url) != ""
  defp has_pr?(_outcome), do: false

  defp normalize_route(route) when is_atom(route), do: route

  defp normalize_route(route) when is_binary(route) do
    route
    |> normalize_status()
    |> case do
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

  defp normalize_route(_route), do: nil

  defp normalize_status(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_status(value) when is_atom(value), do: value |> Atom.to_string() |> normalize_status()
  defp normalize_status(_value), do: nil
end
