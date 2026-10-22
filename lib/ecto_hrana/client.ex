defmodule EctoHrana.Client do
  @moduledoc false
  # libSQL's Hrana protocol over HTTP (the pipeline endpoint, in JSON): each
  # request sends statements on a stream, identified by a baton. A stream is
  # kept open (its baton kept) only during a transaction, and closed otherwise.
  # Hrana 3 is used when the server has it, else Hrana 2, whose pipeline is
  # the same.

  defstruct [:req, :baton, :base_url, pipeline: "/v2/pipeline"]

  @type t :: %__MODULE__{}

  @doc """
  A client for the server at `:uri` (`libsql://`, `https://` or `http://`),
  authenticated with `:auth_token` if given, using the latest version of
  Hrana the server has. `:req_options` are merged into the `Req` request.
  """
  @spec connect(keyword()) :: {:ok, t()} | {:error, EctoHrana.Error.t()}
  def connect(opts) do
    client = new(opts)

    # `GET /v3` succeeds when the server has Hrana 3 over HTTP, with JSON.
    case Req.get(client.req, url: "/v3") do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, %{client | pipeline: "/v3/pipeline"}}

      {:ok, _response} ->
        {:ok, client}

      {:error, exception} ->
        {:error, %EctoHrana.Error{message: Exception.message(exception)}}
    end
  end

  defp new(opts) do
    headers =
      case Keyword.get(opts, :auth_token) do
        nil -> []
        token -> [authorization: "Bearer " <> token]
      end

    req =
      [
        base_url: opts |> Keyword.fetch!(:uri) |> http_url(),
        headers: headers,
        retry: false,
        receive_timeout: Keyword.get(opts, :timeout, 15_000)
      ]
      |> Req.new()
      |> Req.merge(Keyword.get(opts, :req_options, []))

    %__MODULE__{req: req}
  end

  defp http_url("libsql://" <> rest), do: "https://" <> rest
  defp http_url(url), do: url

  @doc """
  Runs `sql` with `params`, keeping the stream open if `keep_open?` (in a
  transaction) and closing it otherwise.
  """
  @spec execute(t(), String.t(), list(), boolean()) ::
          {:ok, EctoHrana.Result.t(), t()}
          | {:error, EctoHrana.Error.t(), t()}
          | {:disconnect, EctoHrana.Error.t(), t()}
  def execute(client, sql, params, keep_open?) do
    stmt = %{sql: sql, args: Enum.map(params, &encode/1), want_rows: true}
    requests = [%{type: "execute", stmt: stmt} | if(keep_open?, do: [], else: [%{type: "close"}])]

    req =
      if client.base_url, do: Req.merge(client.req, base_url: client.base_url), else: client.req

    case Req.post(req, url: client.pipeline, json: %{baton: client.baton, requests: requests}) do
      {:ok, %{status: 200, body: %{"results" => [result | _]} = body}} ->
        client =
          if keep_open?,
            do: %{client | baton: body["baton"], base_url: body["base_url"] || client.base_url},
            else: %{client | baton: nil, base_url: nil}

        case result do
          %{"type" => "ok", "response" => %{"result" => result}} ->
            {:ok, decode_result(result), client}

          %{"type" => "error", "error" => error} ->
            {:error, error(error, sql), client}
        end

      {:ok, %{status: status, body: body}} ->
        {:disconnect,
         %EctoHrana.Error{message: "HTTP #{status}: #{inspect(body)}", statement: sql},
         %{client | baton: nil, base_url: nil}}

      {:error, exception} ->
        {:disconnect, %EctoHrana.Error{message: Exception.message(exception), statement: sql},
         %{client | baton: nil, base_url: nil}}
    end
  end

  # Without the server's prefix, the message is SQLite's, as ecto_sqlite3
  # expects it to find the constraints.
  defp error(%{"message" => message} = error, sql) do
    %EctoHrana.Error{
      message: String.replace_prefix(message, "SQLite error: ", ""),
      code: error["code"],
      statement: sql
    }
  end

  defp decode_result(%{"cols" => cols, "rows" => rows} = result) do
    # Ecto expects no rows (nil), and the count of changed rows, from a
    # statement returning no columns.
    {rows, num_rows} =
      case cols do
        [] -> {nil, result["affected_row_count"] || 0}
        _ -> {Enum.map(rows, fn row -> Enum.map(row, &decode/1) end), length(rows)}
      end

    %EctoHrana.Result{
      columns: Enum.map(cols, & &1["name"]),
      rows: rows,
      num_rows: num_rows,
      last_insert_id: parse_integer(result["last_insert_rowid"])
    }
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_binary(value), do: String.to_integer(value)
  defp parse_integer(value) when is_integer(value), do: value

  # Values as ecto_sqlite3's dumpers give them; binaries are TEXT unless
  # tagged `{:blob, binary}` (or not valid UTF-8), as exqlite binds them.
  defp encode(nil), do: %{type: "null"}
  defp encode(true), do: encode(1)
  defp encode(false), do: encode(0)

  defp encode(value) when is_integer(value),
    do: %{type: "integer", value: Integer.to_string(value)}

  defp encode(value) when is_float(value), do: %{type: "float", value: value}
  defp encode({:blob, value}), do: %{type: "blob", base64: Base.encode64(value)}

  defp encode(value) when is_binary(value) do
    if String.valid?(value),
      do: %{type: "text", value: value},
      else: encode({:blob, value})
  end

  defp encode(%Decimal{} = value), do: encode(Decimal.to_string(value, :normal))
  defp encode(%Date{} = value), do: encode(Date.to_iso8601(value))
  defp encode(%Time{} = value), do: encode(Time.to_iso8601(value))
  defp encode(%NaiveDateTime{} = value), do: encode(NaiveDateTime.to_iso8601(value))
  defp encode(%DateTime{} = value), do: encode(DateTime.to_iso8601(value))

  defp encode(value) do
    raise ArgumentError, "unsupported parameter: #{inspect(value)}"
  end

  defp decode(%{"type" => "null"}), do: nil
  defp decode(%{"type" => "integer", "value" => value}), do: String.to_integer(value)
  defp decode(%{"type" => "float", "value" => value}), do: value / 1
  defp decode(%{"type" => "text", "value" => value}), do: value
  defp decode(%{"type" => "blob", "base64" => value}), do: Base.decode64!(value, padding: false)
end
