defmodule Timeclock.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TimeclockWeb.Telemetry,
      Timeclock.Repo,
      {DNSCluster, query: Application.get_env(:timeclock, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Timeclock.PubSub},
      # Start a worker by calling: Timeclock.Worker.start_link(arg)
      # {Timeclock.Worker, arg},
      # Start to serve requests, typically the last entry
      TimeclockWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Timeclock.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TimeclockWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
