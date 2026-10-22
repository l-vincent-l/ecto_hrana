defmodule EctoHrana do
  @moduledoc """
  Ecto adapter and `DBConnection` driver for libSQL servers (Turso, Bunny
  Database, `sqld`), over libSQL's Hrana protocol on HTTP, in pure Elixir.

  libSQL is a fork of SQLite: a libSQL server speaks SQLite's SQL dialect.
  So instead of generating SQL itself, this library reuses `ecto_sqlite3`'s
  SQL generation, migrations, loaders/dumpers and constraint errors, and only
  brings what differs, the way statements reach the database:

    * `Ecto.Adapters.Hrana` - the Ecto adapter, to use in a repo;
    * `EctoHrana.Connection` - the `DBConnection` driver, which can be used
      without Ecto;
    * `EctoHrana.Query`, `EctoHrana.Result` and `EctoHrana.Error` - its
      statements, results and errors.

  ## Hrana

  Hrana is libSQL's client/server protocol, the one Turso's and Bunny's
  official clients speak behind `libsql://` URLs. Over HTTP, a client posts a
  *pipeline* of requests (execute a statement, close the stream...) to the
  server. Requests are run on a *stream*, a connection on the server side; a
  *baton* returned with each response lets the next pipeline continue on the
  same stream. Hrana 3 is used when the server has it (`GET /v3` succeeds),
  else Hrana 2, whose pipeline is the same in JSON.

  See the [Hrana specification](https://github.com/tursodatabase/libsql/blob/main/docs/HRANA_3_SPEC.md).

  ## Status

  A prototype: it passes its tests against `sqld` and a full Ash application
  test suite, but has not been used against a remote server in production.
  See the limitations in `Ecto.Adapters.Hrana`.
  """
end
