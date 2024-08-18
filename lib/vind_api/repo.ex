defmodule VindApi.Repo do
  use Ecto.Repo,
    otp_app: :vind_api,
    adapter: Ecto.Adapters.SQLite3
end
