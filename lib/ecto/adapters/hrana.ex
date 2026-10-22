defmodule Ecto.Adapters.Hrana do
  @moduledoc """
  Ecto adapter for libSQL servers (Turso, Bunny Database, `sqld`), over the
  Hrana protocol on HTTP, in pure Elixir.

  libSQL speaks SQLite's dialect: the SQL generation, the migrations, the
  loaders and dumpers, and the constraint errors are `ecto_sqlite3`'s, so
  they behave the same, with the same application environment
  (`config :ecto_sqlite3, uuid_type: ...`). Only the driver differs, see
  `EctoHrana.Connection` for its options:

      config :my_app, MyApp.Repo,
        uri: "libsql://my-db.turso.io",
        auth_token: System.fetch_env!("LIBSQL_AUTH_TOKEN")

  The database is the server's: it is neither created nor dropped by
  `mix ecto.create` / `mix ecto.drop`.
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
