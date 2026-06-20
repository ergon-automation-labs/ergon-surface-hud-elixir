defmodule ErgonSurfaceMentraGlassElixirWeb.BotEventsController do
  use ErgonSurfaceMentraGlassElixirWeb, :controller

  require Logger

  def post_update(conn, %{"bot" => bot_name, "message" => message, "status" => status}) do
    Logger.info("Update from #{bot_name}: #{message} (#{status})")

    update = %{
      agent: bot_name,
      message: message,
      status: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Broadcast to all connected clients
    Phoenix.PubSub.broadcast(
      ErgonSurfaceMentraGlassElixir.PubSub,
      "bot_updates",
      {:task_update, update}
    )

    json(conn, %{
      status: "ok",
      action: "post_update",
      bot: bot_name,
      message: "Update received and broadcasted",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def post_update(conn, _params) do
    json(conn, %{
      status: "error",
      error: "bot, message, and status parameters required"
    })
  end

  def subscribe(conn, %{"bot" => bot_name}) do
    Logger.info("Bot #{bot_name} subscribing to events")

    json(conn, %{
      status: "ok",
      action: "subscribe",
      bot: bot_name,
      channel: "bot_updates",
      message: "Subscription established",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def subscribe(conn, _params) do
    json(conn, %{status: "error", error: "bot parameter required"})
  end

  def health_check(conn, %{"bot" => bot_name}) do
    Logger.debug("Health check from bot: #{bot_name}")

    json(conn, %{
      status: "ok",
      bot: bot_name,
      system_status: "healthy",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def health_check(conn, _params) do
    json(conn, %{status: "ok", system_status: "healthy"})
  end
end
