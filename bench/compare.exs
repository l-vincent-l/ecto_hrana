# Compares Ecto.Adapters.Hrana with ecto_libsql's remote mode, against the same
# libSQL server (HRANA_URL, default http://127.0.0.1:8080):
#
#     MIX_ENV=dev mix run bench/compare.exs

defmodule Bench.HranaRepo do
  use Ecto.Repo, otp_app: :ecto_hrana, adapter: Ecto.Adapters.Hrana
end

defmodule Bench.LibSqlRepo do
  use Ecto.Repo, otp_app: :ecto_hrana, adapter: Ecto.Adapters.LibSql
end

defmodule Bench.Item do
  use Ecto.Schema

  schema "bench_items" do
    field(:name, :string)
    field(:n, :integer)
  end
end

defmodule Bench do
  import Ecto.Query
  alias Bench.Item

  @inserts 300
  @gets 300
  @transactions 50

  def run(repo) do
    Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS bench_items")
    Ecto.Adapters.SQL.query!(repo, "CREATE TABLE bench_items (id INTEGER PRIMARY KEY, name TEXT, n INTEGER)")

    [
      {"#{@inserts} inserts", fn -> for n <- 1..@inserts, do: repo.insert!(%Item{name: "item #{n}", n: n}) end},
      {"#{@gets} gets by id", fn -> for id <- 1..@gets, do: repo.get!(Item, id) end},
      {"select #{@inserts} rows x 20", fn -> for _ <- 1..20, do: repo.all(from(i in Item)) end},
      {"#{@transactions} transactions (2 writes)",
       fn ->
         for n <- 1..@transactions do
           repo.transaction(fn ->
             repo.insert!(%Item{name: "tx #{n}", n: n})
             repo.update_all(from(i in Item, where: i.n == ^n), inc: [n: 1])
           end)
         end
       end},
      {"#{@gets} gets, 10 concurrent",
       fn ->
         1..@gets
         |> Task.async_stream(&repo.get!(Item, &1), max_concurrency: 10, timeout: :infinity)
         |> Stream.run()
       end}
    ]
    |> Enum.map(fn {label, fun} -> {label, best_of(3, fun)} end)
  end

  defp best_of(times, fun) do
    1..times |> Enum.map(fn _ -> fun |> :timer.tc() |> elem(0) end) |> Enum.min() |> div(1000)
  end
end

url = System.get_env("HRANA_URL", "http://127.0.0.1:8080")
Logger.configure(level: :warning)

{:ok, _} = Bench.HranaRepo.start_link(uri: url, pool_size: 10, log: false)
{:ok, _} = Bench.LibSqlRepo.start_link(uri: url, auth_token: "unused", pool_size: 10, log: false)

hrana = Bench.run(Bench.HranaRepo)
libsql = Bench.run(Bench.LibSqlRepo)

IO.puts(String.pad_trailing("", 32) <> "  hrana (ms)  ecto_libsql (ms)")

for {{label, h}, {_, l}} <- Enum.zip(hrana, libsql) do
  IO.puts(
    String.pad_trailing(label, 32) <>
      String.pad_leading("#{h}", 12) <> String.pad_leading("#{l}", 18)
  )
end
