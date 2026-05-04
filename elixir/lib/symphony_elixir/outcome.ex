defmodule SymphonyElixir.Outcome do
  @moduledoc """
  Normalized agent-reported outcome data.
  """

  defstruct [
    :status,
    :validation,
    :pr_url,
    :merged,
    unresolved_comments: false
  ]

  @type t :: %__MODULE__{
          status: String.t() | nil,
          validation: String.t() | nil,
          pr_url: String.t() | nil,
          merged: boolean() | nil,
          unresolved_comments: boolean()
        }

  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(arguments) when is_map(arguments) do
    {:ok,
     %__MODULE__{
       status: optional_string(arguments, "status"),
       validation: optional_string(arguments, "validation"),
       pr_url: optional_string(arguments, "pr_url"),
       merged: optional_boolean(arguments, "merged"),
       unresolved_comments: optional_boolean(arguments, "unresolved_comments") || false
     }}
  end

  def from_map(_arguments), do: {:error, :invalid_arguments}

  defp optional_string(arguments, field) do
    value = Map.get(arguments, field) || Map.get(arguments, String.to_atom(field))

    case value do
      value when is_binary(value) ->
        value
        |> String.trim()
        |> case do
          "" -> nil
          trimmed -> trimmed
        end

      _ ->
        nil
    end
  end

  defp optional_boolean(arguments, field) do
    value = Map.get(arguments, field) || Map.get(arguments, String.to_atom(field))

    case value do
      value when is_boolean(value) -> value
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end
end
