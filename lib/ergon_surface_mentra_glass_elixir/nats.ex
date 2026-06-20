defmodule ErgonSurfaceMentraGlassElixir.NATS do
  require Logger

  def query_bridge(message) do
    host = System.get_env("NATS_HOST", "localhost")
    port = String.to_integer(System.get_env("NATS_PORT", "4222"))

    # Use Task with timeout to prevent hanging
    task = Task.async(fn -> do_query_bridge(host, port, message) end)

    case Task.yield(task, 5000) do
      {:ok, result} ->
        result

      nil ->
        Task.shutdown(task, :brutal_kill)
        Logger.error("NATS query timeout")
        mock_response(message)
    end
  end

  defp do_query_bridge(host, port, message) do
    try do
      {:ok, nc} = Gnat.start_link(host: host, port: port)

      payload = Jason.encode!(%{query: message})

      case Gnat.request(nc, "bridge.chat", payload, timeout: 3000) do
        {:ok, response} ->
          {:ok, Jason.decode!(response.body)}

        {:error, reason} ->
          Logger.error("NATS request error: #{inspect(reason)}")
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
      {:msg, _sub, msg} ->
        try do
          data = Jason.decode!(msg.body)

          update = %{
            agent: data["agent"] || "agent",
            message: data["description"] || "Update",
            status: data["status"] || "info",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }

          send(pid, {:task_update, update})
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
end
