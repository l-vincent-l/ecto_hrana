defmodule EctoHrana.Query do
  @moduledoc """
  A SQL statement. Hrana runs statements from their text: nothing is prepared
  on the server.
  """
  defstruct name: "", statement: nil

  @type t :: %__MODULE__{name: String.t(), statement: String.t()}

  defimpl DBConnection.Query do
    def parse(query, _opts), do: query
    def describe(query, _opts), do: query
    def encode(_query, params, _opts), do: params
    def decode(_query, result, _opts), do: result
  end

  defimpl String.Chars do
    def to_string(%{statement: statement}), do: statement
  end
end
