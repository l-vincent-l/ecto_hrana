defmodule EctoHrana.Error do
  @moduledoc """
  An error of the server or of the transport.

    * `:message` - for a server error, SQLite's message, e.g.
      `"UNIQUE constraint failed: users.name"` (the server's
      `"SQLite error: "` prefix is removed, so that `ecto_sqlite3` recognises
      constraint errors);
    * `:code` - the SQLite error code, e.g. `"SQLITE_CONSTRAINT_UNIQUE"`, or
      `nil` for a transport error (network, HTTP status);
    * `:statement` - the SQL of the statement that failed.
  """
  defexception [:message, :code, :statement]

  @type t :: %__MODULE__{
          message: String.t(),
          code: String.t() | nil,
          statement: String.t() | nil
        }
end
