# EctoHrana

Prototype of an Ecto adapter for libSQL servers (Turso, Bunny Database,
`sqld`), over the Hrana protocol on HTTP, in pure Elixir.

libSQL speaks SQLite's dialect, so the SQL generation, the migrations, the
loaders/dumpers and the constraint errors are `ecto_sqlite3`'s: only the driver
(`EctoHrana.Connection`) is new.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Hrana
end

config :my_app, MyApp.Repo,
  uri: "libsql://my-db.turso.io",
  auth_token: System.fetch_env!("LIBSQL_AUTH_TOKEN")
```

The tests and `bench/compare.exs` need a libSQL server:

    docker run -p 127.0.0.1:8080:8080 ghcr.io/tursodatabase/libsql-server:latest

## License

MIT, see [LICENSE](LICENSE).
