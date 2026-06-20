defmodule ErgonSurfaceMentraGlassElixirWeb.BotChatController do
  use ErgonSurfaceMentraGlassElixirWeb, :controller

  require Logger

  def send_message(conn, %{"message" => message, "bot" => bot_name}) do
    Logger.info("Bot #{bot_name} sending message: #{message}")

    # Send via NATS bridge.chat
    case ErgonSurfaceMentraGlassElixir.NATS.query_bridge(message) do
      {:ok, response} ->
        response_text = response["data"]["response"] || response["response"] || "No response"

        json(conn, %{
          status: "ok",
          message: message,
          response: response_text,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          bot: bot_name
        })

      {:error, reason} ->
        json(conn, %{status: "error", error: reason, message: message})
    end
  end

  def send_message(conn, %{"message" => _message}) do
    json(conn, %{status: "error", error: "bot parameter required"})
  end

  def send_message(conn, _params) do
    json(conn, %{status: "error", error: "message and bot parameters required"})
  end

  def query(conn, %{"query" => query_text}) do
    Logger.info("Bot query: #{query_text}")

    case ErgonSurfaceMentraGlassElixir.NATS.query_bridge(query_text) do
      {:ok, response} ->
        response_text = response["data"]["response"] || response["response"] || "No response"

        json(conn, %{
          status: "ok",
          query: query_text,
          response: response_text,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        json(conn, %{status: "error", error: reason, query: query_text})
    end
  end

  def query(conn, _params) do
    json(conn, %{status: "error", error: "query parameter required"})
  end

  def history(conn, params) do
    limit = String.to_integer(params["limit"] || "20")

    # Mock chat history
    history = [
      %{
        role: "user",
        message: "What are my top priorities?",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        role: "assistant",
        message: "Your top priorities are...",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]

    json(conn, %{
      history: Enum.take(history, limit),
      count: length(history)
    })
  end
end
