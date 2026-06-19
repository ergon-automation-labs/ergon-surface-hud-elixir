defmodule ErgonSurfaceMentraGlassElixirWeb.APIController do
  use ErgonSurfaceMentraGlassElixirWeb, :controller

  def health(conn, _params) do
    json(conn, %{status: "ok", surface: "mentra-glass"})
  end

  def debug(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      environment: %{
        port: System.get_env("PORT", "3000"),
        package_name: System.get_env("PACKAGE_NAME", "com.ergon.mentra-glass"),
        mentra_os_api_key:
          if(System.get_env("MENTRA_OS_API_KEY"), do: "***set***", else: "***missing***"),
        nats_host: System.get_env("NATS_HOST", "localhost"),
        nats_port: System.get_env("NATS_PORT", "4222")
      },
      endpoints: %{
        webview: "/webview",
        api_health: "/api/health",
        api_debug: "/api/debug",
        app_json: "/app.json"
      }
    })
  end

  def app_json(conn, _params) do
    json(conn, %{
      name: "mentra-glass",
      packageName: System.get_env("PACKAGE_NAME", "com.ergon.mentra-glass"),
      displayName: "Mentra Glass",
      version: "0.2.7",
      description: "Direct AI interaction with Bot Army — Real-time HUD with chat",
      author: %{
        name: "Bot Army",
        website: "https://botarmy.ai"
      },
      webview: %{
        url: "/webview",
        width: 700,
        height: 900
      },
      permissions: ["network"],
      settings: %{
        apiKey: System.get_env("MENTRA_OS_API_KEY", "")
      }
    })
  end
end
