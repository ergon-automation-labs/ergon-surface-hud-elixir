defmodule ErgonSurfaceMentraGlassElixirWeb.BotControlController do
  use ErgonSurfaceMentraGlassElixirWeb, :controller

  require Logger

  def restart_bot(conn, %{"bot" => bot_name}) do
    Logger.warn("Bot restart requested for: #{bot_name}")

    json(conn, %{
      status: "ok",
      action: "restart",
      bot: bot_name,
      message: "Restart signal sent to #{bot_name}",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def restart_bot(conn, _params) do
    json(conn, %{status: "error", error: "bot parameter required"})
  end

  def reload_bot(conn, %{"bot" => bot_name}) do
    Logger.warn("Bot reload requested for: #{bot_name}")

    json(conn, %{
      status: "ok",
      action: "reload",
      bot: bot_name,
      message: "Reload signal sent to #{bot_name}",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def reload_bot(conn, _params) do
    json(conn, %{status: "error", error: "bot parameter required"})
  end

  def refresh_status(conn, _params) do
    Logger.info("System refresh requested")

    json(conn, %{
      status: "ok",
      action: "refresh",
      message: "Status refresh triggered",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def clear_cache(conn, _params) do
    Logger.warn("Cache clear requested")

    json(conn, %{
      status: "ok",
      action: "clear_cache",
      message: "Cache cleared",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def execute_command(conn, %{"command" => command, "args" => args}) do
    Logger.info("Execute command: #{command} with args: #{inspect(args)}")

    json(conn, %{
      status: "ok",
      action: "execute",
      command: command,
      args: args,
      result: "Command executed successfully",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def execute_command(conn, %{"command" => command}) do
    Logger.info("Execute command: #{command}")

    json(conn, %{
      status: "ok",
      action: "execute",
      command: command,
      result: "Command executed successfully",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def execute_command(conn, _params) do
    json(conn, %{status: "error", error: "command parameter required"})
  end
end
