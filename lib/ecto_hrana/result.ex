defmodule EctoHrana.Result do
  @moduledoc """
  The result of a statement.

    * `:columns` - the names of the returned columns;
    * `:rows` - the returned rows, as lists of values; `nil` for a statement
      returning no columns (an `INSERT` without `RETURNING`, a DDL statement);
    * `:num_rows` - the number of rows returned, or, when `rows` is `nil`, the
      number of rows the statement changed;
    * `:last_insert_id` - the rowid of the last row inserted, if any.
  """
  defstruct columns: [], rows: [], num_rows: 0, last_insert_id: nil

  @type t :: %__MODULE__{
          columns: [String.t()],
          rows: [list()] | nil,
          num_rows: non_neg_integer(),
          last_insert_id: integer() | nil
        }
end
