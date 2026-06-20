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
        api_config: "/api/config",
        app_json: "/app.json"
      }
    })
  end

  def config(conn, _params) do
    # Return the NATS configuration for the webview to use
    # Use WebSocket connection (port 14222) for browser-based clients
    nats_servers = System.get_env("NATS_SERVERS", "ws://localhost:14222")

    json(conn, %{
      nats: %{
        servers: String.split(nats_servers, ","),
        protocol: "websocket"
      },
      bridge: %{
        chat_subject: "bridge.chat",
        timeout_ms: 30000
      },
      tls: %{
        certificate_url: "/api/certificate",
        certificate_format: "pem"
      }
    })
  end

  def certificate(conn, %{"format" => format}) when format in ["pem", "der"] do
    cert_path =
      case format do
        "pem" -> "/var/lib/bot_army/certs/mentra-glass.pem"
        "der" -> "/var/lib/bot_army/certs/mentra-glass.der"
      end

    if File.exists?(cert_path) do
      content = File.read!(cert_path)

      content_type =
        if format == "der", do: "application/x-x509-ca-cert", else: "application/x-pem-file"

      conn
      |> put_resp_content_type(content_type)
      |> send_resp(200, content)
    else
      send_resp(conn, 404, "Certificate not found")
    end
  end

  def certificate(conn, _params) do
    # Default to PEM format
    certificate(conn, %{"format" => "pem"})
  end

  def app_json(conn, _params) do
    json(conn, %{
      name: "mentra-glass",
      packageName: System.get_env("PACKAGE_NAME", "com.ergon.mentra-glass"),
      displayName: "Mentra Glass",
      version: "0.2.12",
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
      },
      tls: %{
        certificatePath: "/certs/mentra-glass.pem",
        certificateUrl: "/static/certs/mentra-glass.pem"
      }
    })
  end
end
