defmodule EctoHrana.Error do
  @moduledoc """
  An error of the server (`code` is the SQLite error code, e.g.
  `"SQLITE_CONSTRAINT_UNIQUE"`) or of the transport (`code` is `nil`).
  """
  defexception [:message, :code, :statement]
end
