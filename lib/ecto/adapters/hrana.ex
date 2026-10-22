defmodule Ecto.Adapters.Hrana do
  @moduledoc """
  Ecto adapter for libSQL servers (Turso, Bunny Database, `sqld`), over the
  Hrana protocol on HTTP, in pure Elixir: no NIF, nothing to compile.

  libSQL speaks SQLite's dialect, so the SQL generation, the migrations, the
  loaders and dumpers, and the constraint errors are `ecto_sqlite3`'s
  (`Ecto.Adapters.SQLite3`): queries behave as they do on a local SQLite
  file. Only the driver, `EctoHrana.Connection`, is different.

  ## Configuration

      defmodule MyApp.Repo do
        use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Hrana
      end

      config :my_app, MyApp.Repo,
        uri: System.fetch_env!("LIBSQL_URL"),
        auth_token: System.fetch_env!("LIBSQL_AUTH_TOKEN"),
        pool_size: 10

  Options, besides the usual repo and pool options (`:pool_size`,
  `:queue_target`...):

    * `:uri` - the server's URL (required). `libsql://` URLs, as given by Turso
      and Bunny, are reached over HTTPS; `https://` and `http://` are used as
      they are (`http://` for a local `sqld`);
    * `:auth_token` - the database's token, sent as a bearer token. Not needed
      by a local `sqld` started without authentication;
    * `:timeout` - how long to wait for each response, in milliseconds
      (default `15_000`);
    * `:req_options` - options merged into the `Req` requests, e.g. to tune the
      HTTP connection pool or to plug a fake server in tests.

  ### Turso

      config :my_app, MyApp.Repo,
        uri: "libsql://my-db-my-org.turso.io",
        auth_token: System.fetch_env!("TURSO_AUTH_TOKEN")

  ### Bunny Database

  `bunny db create --token --save-env` gives the URL and a token:

      config :my_app, MyApp.Repo,
        uri: System.fetch_env!("BUNNY_DATABASE_URL"),
        auth_token: System.fetch_env!("BUNNY_DATABASE_AUTH_TOKEN")

  ### A local server

  `sqld`, libSQL's server, runs without authentication:

      docker run -p 127.0.0.1:8080:8080 ghcr.io/tursodatabase/libsql-server:latest

      config :my_app, MyApp.Repo,
        uri: "http://127.0.0.1:8080"

  ## Types

  Values are stored as `ecto_sqlite3` stores them, and its application
  environment applies, e.g. to store UUIDs as BLOBs:

      config :ecto_sqlite3, uuid_type: :binary, binary_id_type: :binary

  See `Ecto.Adapters.SQLite3` for these options (`:uuid_type`,
  `:binary_id_type`, `:map_type`, `:array_type`, `:datetime_type`...).
  Binaries are sent as BLOBs, so they keep their NUL bytes.

  ## Transactions

  Outside a transaction, each statement is one HTTP request, on a stream that
  the request closes. A transaction keeps a stream open, from its `BEGIN` to
  its `COMMIT` or `ROLLBACK`: the statements in between are run on it. Its
  `:mode` option (`:deferred`, the default, `:immediate` or `:exclusive`)
  chooses the `BEGIN`.

  As with any Ecto adapter, a transaction nested in another one is part of
  it: rolling the inner one back rolls the whole transaction back. Savepoints
  are used by statements run with `mode: :savepoint` and by
  `Ecto.Adapters.SQL.Sandbox`, which works as with other adapters.

  The server closes a stream left idle for some time (seconds, depending on
  the server): keep transactions short.

  ## Migrations

  Migrations run as with `ecto_sqlite3`, each in a transaction. The database
  is the server's: `mix ecto.create` does nothing (it is reported as already
  up) and `mix ecto.drop` fails.

  ## Performance

  Each statement is an HTTP round trip to the server: against a remote
  server, the network latency dominates. Keep the application close to the
  database, avoid N+1 queries, and prefer fewer statements returning more
  rows. Results are decoded from JSON, which is fast even for many rows.

  ## Use with Ash

  `ash_sqlite` accepts this adapter, but it checks the repos' adapter against
  the ones it knows and warns at compile time ("Expected a repo using
  `Ecto.Adapters.SQLite3` or `Ecto.Adapters.LibSql`"). The warning is
  harmless.

  ## Limitations

    * no `EXPLAIN` (`Ecto.Adapters.SQL.explain/4`) nor `query_many/4`;
    * streams are emulated: `Repo.stream/2` fetches all the rows at once;
    * no embedded replicas (a local copy synchronised with the server), which
      need libSQL's native library;
    * the SQL generation comes from `ecto_sqlite3`'s internal modules, so the
      `ecto_sqlite3` versions this library works with are pinned.
  """

  use Ecto.Adapters.SQL, driver: :ecto_hrana

  @behaviour Ecto.Adapter.Storage

  @impl Ecto.Adapter.Storage
  def storage_up(_opts), do: {:error, :already_up}

  @impl Ecto.Adapter.Storage
  def storage_down(_opts), do: {:error, "a libSQL server's database cannot be dropped"}

  @impl Ecto.Adapter.Storage
  def storage_status(_opts), do: :up

  @impl Ecto.Adapter.Migration
  def supports_ddl_transaction?, do: true

  @impl Ecto.Adapter.Migration
  def lock_for_migrations(_meta, _opts, fun), do: fun.()

  @impl Ecto.Adapter.Schema
  defdelegate autogenerate(type), to: Ecto.Adapters.SQLite3

  @impl Ecto.Adapter
  defdelegate loaders(primitive_type, ecto_type), to: Ecto.Adapters.SQLite3

  @impl Ecto.Adapter
  defdelegate dumpers(primitive_type, ecto_type), to: Ecto.Adapters.SQLite3
end
