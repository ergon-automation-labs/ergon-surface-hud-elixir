defmodule ErgonSurfaceHudElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ErgonSurfaceHudElixirWeb.Telemetry,
      {DNSCluster,
       query:
         Application.get_env(:ergon_surface_mentra_glass_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ErgonSurfaceHudElixir.PubSub},
      {Gnat.ConnectionPool,
       [
         name: :hud_nats,
         servers: [
           %{
             host: System.get_env("NATS_HOST", "localhost"),
             port: String.to_integer(System.get_env("NATS_PORT", "4222"))
           }
         ]
       ]},
      # Start a worker by calling: ErgonSurfaceHudElixir.Worker.start_link(arg)
      # {ErgonSurfaceHudElixir.Worker, arg},
      # Start to serve requests, typically the last entry
      ErgonSurfaceHudElixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ErgonSurfaceHudElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ErgonSurfaceHudElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
