defmodule ErgonSurfaceMentraGlassElixir.NATS do
  require Logger

  def query_bridge(message) do
    host = System.get_env("NATS_HOST", "localhost")
    port = String.to_integer(System.get_env("NATS_PORT", "4222"))

    try do
      {:ok, nc} = Gnat.start_link(host: host, port: port)

      payload = Jason.encode!(%{query: message})

      case Gnat.request(nc, "bridge.chat", payload, timeout: 30000) do
        {:ok, response} ->
          {:ok, Jason.decode!(response.body)}

        {:error, reason} ->
          Logger.error("NATS request error: #{inspect(reason)}")
          {:error, "NATS request failed"}
      end
    rescue
      e ->
        Logger.error("NATS error: #{inspect(e)}")
        {:error, "Connection failed"}
    end
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
