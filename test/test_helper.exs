# The tests need a libSQL server, e.g.:
#
#     docker run -p 127.0.0.1:8080:8080 ghcr.io/tursodatabase/libsql-server:latest
#
# HRANA_URL (default http://127.0.0.1:8080) and HRANA_AUTH_TOKEN select it.
# They drop and recreate their tables in its database.

defmodule EctoHrana.TestRepo do
  use Ecto.Repo, otp_app: :ecto_hrana, adapter: Ecto.Adapters.Hrana
end

Application.put_env(:ecto_hrana, EctoHrana.TestRepo,
  uri: System.get_env("HRANA_URL", "http://127.0.0.1:8080"),
  auth_token: System.get_env("HRANA_AUTH_TOKEN"),
  pool_size: 4
)

{:ok, _} = EctoHrana.TestRepo.start_link()

ExUnit.start()
