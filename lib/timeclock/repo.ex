defmodule Timeclock.Repo do
  use Ecto.Repo,
    otp_app: :timeclock,
    adapter: Ecto.Adapters.Postgres
end
