defmodule Ecto.Adapters.Hrana.Connection do
  @moduledoc false
  # Runs the statements with EctoHrana.Connection; generates them with
  # ecto_sqlite3.

  @behaviour Ecto.Adapters.SQL.Connection

  alias Ecto.Adapters.SQLite3.Connection, as: SQLite3
  alias EctoHrana.Query

  @impl true
  def child_spec(opts) do
    {:ok, _} = Application.ensure_all_started(:db_connection)
    DBConnection.child_spec(EctoHrana.Connection, opts)
  end

  @impl true
  def prepare_execute(conn, name, sql, params, opts) do
    query = %Query{name: name, statement: IO.iodata_to_binary(sql)}

    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, _query, _result} = ok -> ok
      {:error, %EctoHrana.Error{}} = error -> error
      {:error, error} -> raise error
    end
  end

  @impl true
  def execute(conn, %Query{} = query, params, opts) do
    case DBConnection.execute(conn, query, params, opts) do
      {:ok, _query, _result} = ok -> ok
      {:error, %EctoHrana.Error{}} = error -> error
      {:error, error} -> raise error
    end
  end

  def execute(conn, sql, params, opts) do
    case prepare_execute(conn, "", sql, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      error -> error
    end
  end

  @impl true
  def query(conn, sql, params, opts) do
    query = %Query{statement: IO.iodata_to_binary(sql)}

    case DBConnection.execute(conn, query, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      error -> error
    end
  end

  @impl true
  def query_many(_conn, _sql, _params, _opts) do
    raise RuntimeError, "query_many is not supported by the Hrana adapter"
  end

  @impl true
  def stream(conn, sql, params, opts) do
    DBConnection.stream(conn, %Query{statement: IO.iodata_to_binary(sql)}, params, opts)
  end

  @impl true
  def to_constraints(%EctoHrana.Error{message: message}, opts) do
    SQLite3.to_constraints(%Exqlite.Error{message: message}, opts)
  end

  def to_constraints(_error, _opts), do: []

  @impl true
  def explain_query(_conn, _query, _params, _opts) do
    raise RuntimeError, "explain is not supported by the Hrana adapter yet"
  end

  @impl true
  defdelegate all(query), to: SQLite3
  @impl true
  defdelegate update_all(query), to: SQLite3
  @impl true
  defdelegate delete_all(query), to: SQLite3
  @impl true
  defdelegate insert(prefix, table, header, rows, on_conflict, returning, placeholders, opts),
    to: SQLite3

  # ecto_sql also calls it without `opts`.
  defdelegate insert(prefix, table, header, rows, on_conflict, returning, placeholders),
    to: SQLite3

  @impl true
  defdelegate update(prefix, table, fields, filters, returning), to: SQLite3
  @impl true
  defdelegate delete(prefix, table, filters, returning), to: SQLite3
  @impl true
  defdelegate execute_ddl(command), to: SQLite3
  @impl true
  defdelegate ddl_logs(result), to: SQLite3
  @impl true
  defdelegate table_exists_query(table), to: SQLite3
end
