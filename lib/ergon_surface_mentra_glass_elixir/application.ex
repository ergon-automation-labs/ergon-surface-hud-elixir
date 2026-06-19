defmodule ErgonSurfaceMentraGlassElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ErgonSurfaceMentraGlassElixirWeb.Telemetry,
      ErgonSurfaceMentraGlassElixir.Repo,
      {DNSCluster, query: Application.get_env(:ergon_surface_mentra_glass_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ErgonSurfaceMentraGlassElixir.PubSub},
      # Start a worker by calling: ErgonSurfaceMentraGlassElixir.Worker.start_link(arg)
      # {ErgonSurfaceMentraGlassElixir.Worker, arg},
      # Start to serve requests, typically the last entry
      ErgonSurfaceMentraGlassElixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ErgonSurfaceMentraGlassElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ErgonSurfaceMentraGlassElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
