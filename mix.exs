defmodule EctoHrana.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_hrana,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
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
      {:ecto_libsql, "~> 0.9.1", only: :dev}
    ]
  end
end
