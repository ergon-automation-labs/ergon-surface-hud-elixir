import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/ergon_surface_mentra_glass_elixir start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :ergon_surface_mentra_glass_elixir, ErgonSurfaceMentraGlassElixirWeb.Endpoint,
    server: true
end

config :ergon_surface_mentra_glass_elixir, ErgonSurfaceMentraGlassElixirWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  # Mentra Glass is a stateless web surface (no database required)
  # It communicates only with NATS for bridge queries and task updates

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      "JGN0ZXN0a2V5Zm9ybWVudHJhZ2xhc3Nib3Rhcm15c3VyZmFjZXN0YXRlbGVzc2luMTI4Yml0cw=="

  host = System.get_env("PHX_HOST") || "example.com"

  config :ergon_surface_mentra_glass_elixir,
         :dns_cluster_query,
         System.get_env("DNS_CLUSTER_QUERY")

  # For development with self-signed certs, use HTTP instead of HTTPS
  # MentraOS will handle the protocol automatically based on Server URL in console
  config :ergon_surface_mentra_glass_elixir, ErgonSurfaceMentraGlassElixirWeb.Endpoint,
    url: [host: host, port: 50000, scheme: "http"],
    http: [
      port: String.to_integer(System.get_env("PORT", "50000")),
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
