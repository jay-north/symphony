defmodule SymphonyElixir.Codex.DynamicToolTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Codex.DynamicTool
  alias SymphonyElixir.Linear.Issue

  test "tool_specs advertises scoped Linear tools without raw GraphQL" do
    tool_specs = DynamicTool.tool_specs()
    tool_names = Enum.map(tool_specs, & &1["name"])

    assert tool_names == [
             "linear_get_issue",
             "linear_create_comment",
             "linear_update_issue_state",
             "linear_report_outcome"
           ]

    refute "linear_graphql" in tool_names

    assert Enum.find(tool_specs, &(&1["name"] == "linear_get_issue"))["inputSchema"] == %{
             "additionalProperties" => false,
             "properties" => %{
               "issue_id" => %{
                 "description" => "Linear issue UUID or visible identifier such as DEN-53.",
                 "type" => "string"
               }
             },
             "required" => ["issue_id"],
             "type" => "object"
           }
  end

  test "unsupported tools return a failure payload with the supported tool list" do
    response = DynamicTool.execute("linear_graphql", %{"query" => "query Viewer { viewer { id } }"})

    assert response["success"] == false

    assert Jason.decode!(response["output"]) == %{
             "error" => %{
               "message" => ~s(Unsupported dynamic tool: "linear_graphql".),
               "supportedTools" => [
                 "linear_get_issue",
                 "linear_create_comment",
                 "linear_update_issue_state",
                 "linear_report_outcome"
               ]
             }
           }

    assert response["contentItems"] == [
             %{
               "type" => "inputText",
               "text" => response["output"]
             }
           ]
  end

  test "linear_get_issue returns normalized issue metadata" do
    test_pid = self()

    issue = %Issue{
      id: "issue-1",
      identifier: "DEN-53",
      title: "Prepare scope",
      description: "Readiness pass",
      priority: 3,
      state: "Backlog",
      branch_name: "codex/DEN-53",
      url: "https://linear.app/dentalowl/issue/DEN-53",
      assignee_id: "user-1",
      labels: ["feature"],
      blocked_by: [%{id: "issue-0", identifier: "DEN-52", state: "Done"}],
      assigned_to_worker: true
    }

    response =
      DynamicTool.execute(
        "linear_get_issue",
        %{"issue_id" => " DEN-53 "},
        issue_fetcher: fn issue_id ->
          send(test_pid, {:issue_fetcher_called, issue_id})
          {:ok, issue}
        end
      )

    assert_received {:issue_fetcher_called, "DEN-53"}
    assert response["success"] == true

    assert %{"issue" => issue_payload} = Jason.decode!(response["output"])
    assert issue_payload["id"] == "issue-1"
    assert issue_payload["identifier"] == "DEN-53"
    assert issue_payload["state"] == "Backlog"
    assert issue_payload["labels"] == ["feature"]
    assert issue_payload["blockedBy"] == [%{"id" => "issue-0", "identifier" => "DEN-52", "state" => "Done"}]
  end

  test "linear_create_comment delegates to the tracker comment adapter" do
    test_pid = self()

    response =
      DynamicTool.execute(
        "linear_create_comment",
        %{"issue_id" => "DEN-53", "body" => "Ready for Backlog"},
        commenter: fn issue_id, body ->
          send(test_pid, {:commenter_called, issue_id, body})
          :ok
        end
      )

    assert_received {:commenter_called, "DEN-53", "Ready for Backlog"}
    assert response["success"] == true
    assert Jason.decode!(response["output"]) == %{"ok" => true}
  end

  test "linear_update_issue_state delegates to the tracker state adapter" do
    test_pid = self()

    response =
      DynamicTool.execute(
        "linear_update_issue_state",
        %{"issue_id" => "DEN-53", "state" => "Backlog"},
        state_updater: fn issue_id, state ->
          send(test_pid, {:state_updater_called, issue_id, state})
          :ok
        end
      )

    assert_received {:state_updater_called, "DEN-53", "Backlog"}
    assert response["success"] == true
    assert Jason.decode!(response["output"]) == %{"ok" => true}
  end

  test "linear_report_outcome returns Symphony transition decision without mutating state" do
    test_pid = self()

    response =
      DynamicTool.execute(
        "linear_report_outcome",
        %{
          "issue_id" => "DEN-53",
          "route" => "builder",
          "status" => "ready_for_review",
          "validation" => "passed",
          "pr_url" => "https://github.com/acme/repo/pull/53"
        },
        outcome_reporter: fn issue_id, route, outcome, decision ->
          send(test_pid, {:outcome_reported, issue_id, route, outcome.status, decision})
          :ok
        end
      )

    assert_received {:outcome_reported, "DEN-53", "builder", "ready_for_review", {:transition, "In Review", "builder completed PR with validation"}}

    assert response["success"] == true

    assert Jason.decode!(response["output"]) == %{
             "ok" => true,
             "decision" => %{
               "action" => "transition",
               "state" => "In Review",
               "reason" => "builder completed PR with validation"
             }
           }
  end

  test "linear_report_outcome blocks incomplete builder handoffs" do
    response =
      DynamicTool.execute(
        "linear_report_outcome",
        %{
          "issue_id" => "DEN-53",
          "route" => "builder",
          "status" => "ready_for_review",
          "validation" => "failed"
        }
      )

    assert response["success"] == true

    assert Jason.decode!(response["output"]) == %{
             "ok" => true,
             "decision" => %{
               "action" => "blocked",
               "reason" => "builder completion is missing a PR URL or passing validation"
             }
           }
  end

  test "scoped Linear tools validate required string arguments before calling adapters" do
    get_issue =
      DynamicTool.execute(
        "linear_get_issue",
        %{"issue_id" => "   "},
        issue_fetcher: fn _issue_id -> flunk("issue fetcher should not be called") end
      )

    assert get_issue["success"] == false

    assert Jason.decode!(get_issue["output"]) == %{
             "error" => %{
               "message" => "Dynamic Linear tool argument `issue_id` must be a non-empty string."
             }
           }

    create_comment =
      DynamicTool.execute(
        "linear_create_comment",
        %{"issue_id" => "DEN-53"},
        commenter: fn _issue_id, _body -> flunk("commenter should not be called") end
      )

    assert create_comment["success"] == false

    assert Jason.decode!(create_comment["output"]) == %{
             "error" => %{
               "message" => "Dynamic Linear tool argument `body` must be a non-empty string."
             }
           }

    update_state =
      DynamicTool.execute(
        "linear_update_issue_state",
        ["not", "an", "object"],
        state_updater: fn _issue_id, _state -> flunk("state updater should not be called") end
      )

    assert update_state["success"] == false

    assert Jason.decode!(update_state["output"]) == %{
             "error" => %{
               "message" => "Dynamic Linear tools expect a JSON object with the required fields for that tool."
             }
           }

    report_outcome =
      DynamicTool.execute(
        "linear_report_outcome",
        %{"issue_id" => "DEN-53", "route" => "builder"},
        outcome_reporter: fn _issue_id, _route, _outcome, _decision -> flunk("outcome reporter should not be called") end
      )

    assert report_outcome["success"] == false

    assert Jason.decode!(report_outcome["output"]) == %{
             "error" => %{
               "message" => "Dynamic Linear tool argument `status` must be a non-empty string."
             }
           }
  end

  test "scoped Linear tools format adapter failures" do
    missing_token =
      DynamicTool.execute(
        "linear_get_issue",
        %{"issue_id" => "DEN-53"},
        issue_fetcher: fn _issue_id -> {:error, :missing_linear_api_token} end
      )

    assert missing_token["success"] == false

    assert Jason.decode!(missing_token["output"]) == %{
             "error" => %{
               "message" => "Symphony is missing Linear auth. Set `linear.api_key` in `WORKFLOW.md` or export `LINEAR_API_KEY`."
             }
           }

    failed_update =
      DynamicTool.execute(
        "linear_update_issue_state",
        %{"issue_id" => "DEN-53", "state" => "Backlog"},
        state_updater: fn _issue_id, _state -> {:error, :state_not_found} end
      )

    assert Jason.decode!(failed_update["output"]) == %{
             "error" => %{
               "message" => "Dynamic Linear tool execution failed.",
               "reason" => ":state_not_found"
             }
           }
  end
end
