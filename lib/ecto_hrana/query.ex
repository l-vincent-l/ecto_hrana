defmodule EctoHrana.Query do
  @moduledoc """
  A SQL statement, with `?` or `?NNN` placeholders for its parameters.

  Hrana runs statements from their text: nothing is prepared or cached on the
  server, so preparing a query is free and a prepared query never goes stale.
  `name` is kept for `DBConnection`'s and Ecto's statement caches.
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
