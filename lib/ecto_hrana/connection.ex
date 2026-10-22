defmodule EctoHrana.Connection do
  @moduledoc """
  `DBConnection` to a libSQL server (Turso, Bunny Database, `sqld`) over
  Hrana/HTTP. A connection holds no socket: it is the stream of its current
  transaction, if any.

  Options:

    * `:uri` - the server, `libsql://`, `https://` or `http://` (required);
    * `:auth_token` - the token of the database, if it needs one;
    * `:timeout` - how long to wait for a response, in ms (default 15 s);
    * `:req_options` - options merged into the `Req` request.
  """
  use DBConnection

  alias EctoHrana.{Client, Query, Result}

  defstruct [:client, status: :idle]

  @savepoint "ecto_hrana_savepoint"

  @impl true
  def connect(opts), do: {:ok, %__MODULE__{client: Client.new(opts)}}

  @impl true
  def disconnect(_err, %{client: %{baton: nil}}), do: :ok

  def disconnect(_err, state) do
    _ = Client.execute(state.client, "ROLLBACK", [], false)
    :ok
  end

  @impl true
  def checkout(state), do: {:ok, state}

  @impl true
  def ping(state), do: {:ok, state}

  @impl true
  def handle_status(_opts, state), do: {state.status, state}

  @impl true
  def handle_prepare(%Query{} = query, _opts, state), do: {:ok, query, state}

  @impl true
  def handle_execute(%Query{} = query, params, _opts, state) do
    case run(state, query.statement, params) do
      {:ok, result, state} -> {:ok, query, result, state}
      error -> error
    end
  end

  @impl true
  def handle_close(_query, _opts, state), do: {:ok, %Result{}, state}

  @impl true
  def handle_begin(opts, %{status: :idle} = state) do
    sql =
      case Keyword.get(opts, :mode, :deferred) do
        :immediate -> "BEGIN IMMEDIATE"
        :exclusive -> "BEGIN EXCLUSIVE"
        _ -> "BEGIN"
      end

    with {:ok, result, state} <- run(%{state | status: :transaction}, sql, []) do
      {:ok, result, state}
    else
      {kind, error, state} -> {kind, error, %{state | status: :idle}}
    end
  end

  def handle_begin(_opts, %{status: :transaction} = state) do
    run(state, "SAVEPOINT " <> @savepoint, [])
  end

  @impl true
  def handle_commit(opts, %{status: :transaction} = state) do
    case Keyword.get(opts, :mode) do
      :savepoint -> run(state, "RELEASE SAVEPOINT " <> @savepoint, [])
      _ -> finish(state, "COMMIT")
    end
  end

  @impl true
  def handle_rollback(opts, %{status: :transaction} = state) do
    case Keyword.get(opts, :mode) do
      :savepoint ->
        with {:ok, _result, state} <- run(state, "ROLLBACK TO SAVEPOINT " <> @savepoint, []) do
          run(state, "RELEASE SAVEPOINT " <> @savepoint, [])
        end

      _ ->
        finish(state, "ROLLBACK")
    end
  end

  # Cursors are emulated: the whole result is fetched at once.
  @impl true
  def handle_declare(%Query{} = query, params, _opts, state) do
    case run(state, query.statement, params) do
      {:ok, result, state} -> {:ok, query, result, state}
      error -> error
    end
  end

  @impl true
  def handle_fetch(_query, %Result{} = result, _opts, state), do: {:halt, result, state}

  @impl true
  def handle_deallocate(_query, _cursor, _opts, state), do: {:ok, %Result{}, state}

  # Runs a statement, on the transaction's stream if one is open.
  defp run(state, sql, params) do
    case Client.execute(state.client, sql, params, state.status == :transaction) do
      {:ok, result, client} ->
        {:ok, result, %{state | client: client}}

      {:error, error, client} ->
        {:error, error, %{state | client: client}}

      {:disconnect, error, client} ->
        {:disconnect, error, %{state | client: client, status: :idle}}
    end
  end

  # Ends the transaction, and its stream.
  defp finish(state, sql) do
    case Client.execute(state.client, sql, [], false) do
      {:ok, result, client} ->
        {:ok, result, %{state | client: client, status: :idle}}

      {:error, error, client} ->
        {:disconnect, error, %{state | client: client, status: :idle}}

      {:disconnect, error, client} ->
        {:disconnect, error, %{state | client: client, status: :idle}}
    end
  end
end
