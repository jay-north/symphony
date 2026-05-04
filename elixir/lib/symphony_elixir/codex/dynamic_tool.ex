defmodule SymphonyElixir.Codex.DynamicTool do
  @moduledoc """
  Executes client-side tool calls requested by Codex app-server turns.
  """

  alias SymphonyElixir.{Linear.Issue, Tracker}

  @linear_get_issue_tool "linear_get_issue"
  @linear_create_comment_tool "linear_create_comment"
  @linear_update_issue_state_tool "linear_update_issue_state"

  @issue_id_property %{
    "type" => "string",
    "description" => "Linear issue UUID or visible identifier such as DEN-53."
  }
  @linear_get_issue_description """
  Fetch normalized metadata for one Linear issue using Symphony's configured tracker.
  """
  @linear_get_issue_input_schema %{
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["issue_id"],
    "properties" => %{
      "issue_id" => @issue_id_property
    }
  }
  @linear_create_comment_description """
  Create a comment on one Linear issue using Symphony's configured tracker.
  """
  @linear_create_comment_input_schema %{
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["issue_id", "body"],
    "properties" => %{
      "issue_id" => @issue_id_property,
      "body" => %{
        "type" => "string",
        "description" => "Markdown comment body."
      }
    }
  }
  @linear_update_issue_state_description """
  Move one Linear issue to a named workflow state using Symphony's configured tracker.
  """
  @linear_update_issue_state_input_schema %{
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["issue_id", "state"],
    "properties" => %{
      "issue_id" => @issue_id_property,
      "state" => %{
        "type" => "string",
        "description" => "Target Linear workflow state name, such as Backlog or In Review."
      }
    }
  }

  @spec execute(String.t() | nil, term(), keyword()) :: map()
  def execute(tool, arguments, opts \\ []) do
    case tool do
      @linear_get_issue_tool ->
        execute_linear_get_issue(arguments, opts)

      @linear_create_comment_tool ->
        execute_linear_create_comment(arguments, opts)

      @linear_update_issue_state_tool ->
        execute_linear_update_issue_state(arguments, opts)

      other ->
        failure_response(%{
          "error" => %{
            "message" => "Unsupported dynamic tool: #{inspect(other)}.",
            "supportedTools" => supported_tool_names()
          }
        })
    end
  end

  @spec tool_specs() :: [map()]
  def tool_specs do
    [
      %{
        "name" => @linear_get_issue_tool,
        "description" => @linear_get_issue_description,
        "inputSchema" => @linear_get_issue_input_schema
      },
      %{
        "name" => @linear_create_comment_tool,
        "description" => @linear_create_comment_description,
        "inputSchema" => @linear_create_comment_input_schema
      },
      %{
        "name" => @linear_update_issue_state_tool,
        "description" => @linear_update_issue_state_description,
        "inputSchema" => @linear_update_issue_state_input_schema
      }
    ]
  end

  defp execute_linear_get_issue(arguments, opts) do
    issue_fetcher = Keyword.get(opts, :issue_fetcher, &Tracker.fetch_issue/1)

    with {:ok, issue_id} <- required_string(arguments, "issue_id"),
         {:ok, issue} <- issue_fetcher.(issue_id) do
      dynamic_tool_response(true, encode_payload(%{"issue" => issue_payload(issue)}))
    else
      {:error, reason} ->
        failure_response(tool_error_payload(reason))
    end
  end

  defp execute_linear_create_comment(arguments, opts) do
    commenter = Keyword.get(opts, :commenter, &Tracker.create_comment/2)

    with {:ok, issue_id} <- required_string(arguments, "issue_id"),
         {:ok, body} <- required_string(arguments, "body"),
         :ok <- commenter.(issue_id, body) do
      dynamic_tool_response(true, encode_payload(%{"ok" => true}))
    else
      {:error, reason} ->
        failure_response(tool_error_payload(reason))
    end
  end

  defp execute_linear_update_issue_state(arguments, opts) do
    state_updater = Keyword.get(opts, :state_updater, &Tracker.update_issue_state/2)

    with {:ok, issue_id} <- required_string(arguments, "issue_id"),
         {:ok, state} <- required_string(arguments, "state"),
         :ok <- state_updater.(issue_id, state) do
      dynamic_tool_response(true, encode_payload(%{"ok" => true}))
    else
      {:error, reason} ->
        failure_response(tool_error_payload(reason))
    end
  end

  defp required_string(arguments, field) when is_map(arguments) do
    case Map.get(arguments, field) || Map.get(arguments, String.to_atom(field)) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> {:error, {:missing_required_string, field}}
          trimmed -> {:ok, trimmed}
        end

      _ ->
        {:error, {:missing_required_string, field}}
    end
  end

  defp required_string(_arguments, _field), do: {:error, :invalid_arguments}

  defp issue_payload(%Issue{} = issue) do
    %{
      "id" => issue.id,
      "identifier" => issue.identifier,
      "title" => issue.title,
      "description" => issue.description,
      "priority" => issue.priority,
      "state" => issue.state,
      "branchName" => issue.branch_name,
      "url" => issue.url,
      "assigneeId" => issue.assignee_id,
      "labels" => issue.labels,
      "blockedBy" => issue.blocked_by,
      "assignedToWorker" => issue.assigned_to_worker,
      "createdAt" => encode_datetime(issue.created_at),
      "updatedAt" => encode_datetime(issue.updated_at)
    }
  end

  defp issue_payload(issue), do: issue

  defp encode_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp encode_datetime(_datetime), do: nil

  defp failure_response(payload) do
    dynamic_tool_response(false, encode_payload(payload))
  end

  defp dynamic_tool_response(success, output) when is_boolean(success) and is_binary(output) do
    %{
      "success" => success,
      "output" => output,
      "contentItems" => [
        %{
          "type" => "inputText",
          "text" => output
        }
      ]
    }
  end

  defp encode_payload(payload) when is_map(payload) or is_list(payload) do
    Jason.encode!(payload, pretty: true)
  end

  defp encode_payload(payload), do: inspect(payload)

  defp tool_error_payload(:invalid_arguments) do
    %{
      "error" => %{
        "message" => "Dynamic Linear tools expect a JSON object with the required fields for that tool."
      }
    }
  end

  defp tool_error_payload({:missing_required_string, field}) do
    %{
      "error" => %{
        "message" => "Dynamic Linear tool argument `#{field}` must be a non-empty string."
      }
    }
  end

  defp tool_error_payload(:missing_linear_api_token) do
    %{
      "error" => %{
        "message" => "Symphony is missing Linear auth. Set `linear.api_key` in `WORKFLOW.md` or export `LINEAR_API_KEY`."
      }
    }
  end

  defp tool_error_payload({:linear_api_status, status}) do
    %{
      "error" => %{
        "message" => "Linear request failed with HTTP #{status}.",
        "status" => status
      }
    }
  end

  defp tool_error_payload({:linear_api_request, reason}) do
    %{
      "error" => %{
        "message" => "Linear request failed before receiving a successful response.",
        "reason" => inspect(reason)
      }
    }
  end

  defp tool_error_payload(reason) do
    %{
      "error" => %{
        "message" => "Dynamic Linear tool execution failed.",
        "reason" => inspect(reason)
      }
    }
  end

  defp supported_tool_names do
    Enum.map(tool_specs(), & &1["name"])
  end
end
