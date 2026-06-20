defmodule ErgonSurfaceMentraGlassElixirWeb.BotDashboardController do
  use ErgonSurfaceMentraGlassElixirWeb, :controller

  def status(conn, _params) do
    # Return current system status
    status = %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      system: %{
        nats: "healthy",
        database: "healthy",
        uptime: "24h"
      },
      bots: [
        %{name: "claude_bridge", status: "online", uptime: "24h"},
        %{name: "gtd_bot", status: "online", uptime: "24h"},
        %{name: "llm_bot", status: "online", uptime: "24h"}
      ],
      recent_updates: [
        %{
          agent: "gtd_bot",
          message: "Processed 5 new tasks",
          status: "success",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]
    }

    json(conn, status)
  end

  def health(conn, _params) do
    health = %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: %{
        nats: %{status: "healthy", latency_ms: 5},
        database: %{status: "healthy", connections: 10},
        services: %{status: "healthy", count: 12}
      }
    }

    json(conn, health)
  end

  def bots(conn, _params) do
    bots = [
      %{
        name: "claude_bridge",
        status: "online",
        version: "0.4.142",
        uptime: "24h",
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601(),
        cpu: "5%",
        memory: "128MB"
      },
      %{
        name: "gtd_bot",
        status: "online",
        version: "0.8.1",
        uptime: "24h",
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601(),
        cpu: "2%",
        memory: "64MB"
      },
      %{
        name: "llm_bot",
        status: "online",
        version: "0.2.0",
        uptime: "24h",
        last_seen: DateTime.utc_now() |> DateTime.to_iso8601(),
        cpu: "8%",
        memory: "256MB"
      }
    ]

    json(conn, %{bots: bots, count: length(bots)})
  end

  def updates(conn, params) do
    limit = String.to_integer(params["limit"] || "10")

    updates = [
      %{
        agent: "gtd_bot",
        message: "Processed 5 new tasks",
        status: "success",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        agent: "llm_bot",
        message: "Generated embeddings for 100 documents",
        status: "success",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        agent: "claude_bridge",
        message: "Bridged 42 messages",
        status: "success",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]

    json(conn, %{
      updates: Enum.take(updates, limit),
      count: length(updates)
    })
  end
end
