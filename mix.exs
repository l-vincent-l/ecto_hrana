defmodule EctoHrana.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_hrana,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "EctoHrana",
      description: "Ecto adapter for libSQL servers (Turso, Bunny Database) over Hrana on HTTP",
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp docs do
    [
      main: "EctoHrana",
      extras: ["README.md"],
      groups_for_modules: [
        Ecto: [Ecto.Adapters.Hrana],
        Driver: [EctoHrana.Connection, EctoHrana.Query, EctoHrana.Result, EctoHrana.Error]
      ]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.14"},
      # The SQL generation and the types come from ecto_sqlite3's modules, not
      # from a public API: pinned to a minor version.
      {:ecto_sqlite3, "~> 0.26.0"},
      {:db_connection, "~> 2.10"},
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"},
      # only to compare with it (bench/compare.exs)
      {:ecto_libsql, "~> 0.9.1", only: :dev},
      # Req.Test's fake servers
      {:plug, "~> 1.16", only: :test},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end
end
