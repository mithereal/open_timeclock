defmodule Timeclock.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Timeclock.System.Setup

  @impl true
  def start(_type, _args) do
    children = [
      TimeclockWeb.Telemetry,
      Timeclock.Repo,
      {DNSCluster, query: Application.get_env(:timeclock, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:timeclock, :ash_domains),
         Application.fetch_env!(:timeclock, Oban)
       )},
      {Phoenix.PubSub, name: Timeclock.PubSub},
      # Start a worker by calling: Timeclock.Worker.start_link(arg)
      # {Timeclock.Worker, arg},
      # Start to serve requests, typically the last entry
      TimeclockWeb.Presence,
      TimeclockWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :timeclock]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Timeclock.Supervisor]

    Supervisor.start_link(children, opts)
    |> Setup.run()
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TimeclockWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
