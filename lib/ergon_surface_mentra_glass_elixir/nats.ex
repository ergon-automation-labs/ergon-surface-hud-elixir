defmodule ErgonSurfaceHudElixir.NATS do
  require Logger

  def query_bridge(message) do
    host = System.get_env("NATS_HOST", "localhost")
    port = String.to_integer(System.get_env("NATS_PORT", "4222"))

    try do
      {:ok, nc} = Gnat.start_link(host: host, port: port, timeout: 5000)
      payload = Jason.encode!(%{query: message})

      case Gnat.request(nc, "bridge.chat", payload, timeout: 10000) do
        {:ok, response} ->
          {:ok, Jason.decode!(response.body)}

        {:error, reason} ->
          Logger.error("NATS bridge.chat error: #{inspect(reason)}")
          mock_response(message)
      end
    rescue
      e ->
        Logger.error("NATS error: #{inspect(e)}")
        mock_response(message)
    end
  end

  defp mock_response(message) do
    # Demo/fallback response when NATS bridge isn't available
    response = %{
      "response" =>
        "Demo mode: I received your message: '#{message}'. In production, this would be processed by the AI bridge.",
      "data" => %{
        "response" =>
          "Demo mode: I received your message: '#{message}'. In production, this would be processed by the AI bridge."
      }
    }

    {:ok, response}
  end

  def subscribe_to_updates(pid) do
    host = System.get_env("NATS_HOST", "localhost")
    port = String.to_integer(System.get_env("NATS_PORT", "4222"))

    spawn(fn ->
      try do
        {:ok, nc} = Gnat.start_link(host: host, port: port)
        {:ok, _sub} = Gnat.subscribe(nc, "bot_army.task.updated")
        {:ok, _sub} = Gnat.subscribe(nc, "bot_army.notification.*")

        listen_for_updates(nc, pid)
      rescue
        e ->
          Logger.error("Subscribe error: #{inspect(e)}")
      end
    end)

    :ok
  end

  defp listen_for_updates(nc, pid) do
    receive do
      {:msg, sub, msg} ->
        try do
          data = Jason.decode!(msg.body)
          subject = sub.topic

          if String.contains?(subject, "notification") do
            notification = %{
              source: data["source"] || data["bot"] || "Unknown",
              message: data["message"] || data["text"] || "",
              timestamp: format_timestamp()
            }

            send(pid, {:notification, notification})
          else
            update = %{
              agent: data["agent"] || "agent",
              message: data["description"] || "Update",
              status: data["status"] || "info",
              timestamp: format_timestamp()
            }

            send(pid, {:task_update, update})
          end
        rescue
          _ -> :ok
        end

        listen_for_updates(nc, pid)

      _ ->
        listen_for_updates(nc, pid)
    after
      30000 ->
        listen_for_updates(nc, pid)
    end
  rescue
    _ ->
      Logger.error("Listen error, stopping updates")
  end

  defp format_timestamp do
    DateTime.utc_now()
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0..7)
  end
end
