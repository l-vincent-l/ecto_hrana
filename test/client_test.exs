defmodule EctoHrana.ClientTest do
  use ExUnit.Case, async: true

  alias EctoHrana.Client

  # A server answering a pipeline at `pipeline`, and `GET /v3` with `v3_status`.
  defp fake_server(v3_status, pipeline) do
    fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/v3"} ->
          Plug.Conn.send_resp(conn, v3_status, "")

        {"POST", ^pipeline} ->
          Req.Test.json(conn, %{
            "baton" => nil,
            "base_url" => nil,
            "results" => [
              %{
                "type" => "ok",
                "response" => %{
                  "type" => "execute",
                  "result" => %{
                    "cols" => [%{"name" => "x"}],
                    "rows" => [[%{"type" => "integer", "value" => "1"}]],
                    "affected_row_count" => 0
                  }
                }
              },
              %{"type" => "ok", "response" => %{"type" => "close"}}
            ]
          })

        _ ->
          Plug.Conn.send_resp(conn, 404, "")
      end
    end
  end

  defp select_one(v3_status, pipeline) do
    {:ok, client} =
      Client.connect(
        uri: "http://hrana.test",
        req_options: [plug: fake_server(v3_status, pipeline)]
      )

    Client.execute(client, "SELECT 1 AS x", [], false)
  end

  test "uses Hrana 3 when the server has it" do
    assert {:ok, %EctoHrana.Result{rows: [[1]]}, _client} = select_one(200, "/v3/pipeline")
  end

  test "falls back to Hrana 2 when the server lacks Hrana 3" do
    assert {:ok, %EctoHrana.Result{rows: [[1]]}, _client} = select_one(404, "/v2/pipeline")
  end
end
