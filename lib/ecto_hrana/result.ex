defmodule EctoHrana.Result do
  @moduledoc """
  The result of a statement. `num_rows` is the number of rows returned, or,
  for a statement returning no columns (`rows` is then `nil`), the number of
  rows it changed.
  """
  defstruct columns: [], rows: [], num_rows: 0, last_insert_id: nil

  @type t :: %__MODULE__{
          columns: [String.t()],
          rows: [list()] | nil,
          num_rows: non_neg_integer(),
          last_insert_id: integer() | nil
        }
end
