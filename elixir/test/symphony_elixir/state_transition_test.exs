defmodule SymphonyElixir.StateTransitionTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.{Outcome, StateTransition}

  test "planner moves ready issues to In Progress and incomplete issues to Backlog" do
    assert {:transition, "In Progress", "planner reported ready"} =
             StateTransition.decide(:planner, %Outcome{status: "ready"})

    assert {:transition, "Backlog", "planner reported missing acceptance criteria"} =
             StateTransition.decide(:planner, %Outcome{status: "missing_acceptance_criteria"})
  end

  test "builder requires both passing validation and a PR before review transition" do
    assert {:transition, "In Review", "builder completed PR with validation"} =
             StateTransition.decide(:builder, %Outcome{
               status: "ready_for_review",
               validation: "passed",
               pr_url: "https://github.com/acme/repo/pull/1"
             })

    assert {:blocked, "builder completion is missing a PR URL or passing validation"} =
             StateTransition.decide(:builder, %Outcome{status: "ready_for_review", validation: "passed"})
  end

  test "reviewer and land routes compute deterministic transitions" do
    assert {:transition, "Rework", "reviewer found unresolved comments"} =
             StateTransition.decide(:reviewer, %Outcome{unresolved_comments: true})

    assert {:transition, "Merging", "reviewer accepted PR"} =
             StateTransition.decide(:reviewer, %Outcome{status: "ready_to_merge"})

    assert {:transition, "Done", "land route reported merged PR"} =
             StateTransition.decide(:land, %Outcome{merged: true})
  end
end
