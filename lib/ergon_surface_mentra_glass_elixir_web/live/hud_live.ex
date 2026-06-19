defmodule ErgonSurfaceMentraGlassElixir.Web.HUDLive do
  use ErgonSurfaceMentraGlassElixirWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       messages: [],
       current_message: "",
       loading: false,
       system_status: %{nats: "healthy", db: "healthy"},
       bots: [],
       task_updates: []
     )
     |> subscribe_to_updates()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="hud">
      <!-- Status Panel -->
      <div class="status-panel">
        <div class="panel-header">Bot Army Status</div>
        <div class="panel-content">
          <!-- System Health -->
          <div class="status-section">
            <div class="status-section-title">System</div>
            <div id="system-status">
              <%= for {key, status} <- @system_status do %>
                <div class="bot-status">
                  <div class="status-indicator" style={status_color(status)}></div>
                  <span class="bot-name"><%= key %></span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Task Updates -->
          <div class="status-section">
            <div class="status-section-title">Agent Updates</div>
            <div id="task-updates">
              <%= for update <- Enum.reverse(@task_updates) do %>
                <div class="task-update" style={update_color(update.status)}>
                  <div class="task-agent"><%= update.agent %></div>
                  <div class="task-message"><%= update.message %></div>
                  <div class="task-time"><%= format_time(update.timestamp) %></div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Chat Panel -->
      <div class="chat-panel">
        <div class="panel-header">Assistant</div>
        <div class="chat-messages" id="messages" phx-update="stream">
          <%= for {_id, message} <- @messages do %>
            <div class="message <%= message.role %>">
              <div class="message-bubble"><%= message.text %></div>
            </div>
          <% end %>
        </div>
        <div class="chat-input-area">
          <input
            id="message-input"
            type="text"
            placeholder="Ask anything..."
            value={@current_message}
            phx-keydown="send_message"
            phx-change="update_message"
            phx-debounce="300"
            autocomplete="off"
          />
          <button phx-click="send_message" disabled={@loading}>
            <%= if @loading, do: "..." , else: "Send" %>
          </button>
        </div>
      </div>
    </div>

    <style>
      .hud {
        width: 100%;
        height: 100vh;
        display: grid;
        grid-template-columns: 1.5fr 1fr;
        gap: 1px;
        background: #0f172a;
        padding: 1px;
      }

      .status-panel {
        background: #1a1f35;
        border-right: 1px solid #334155;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
      }

      .panel-header {
        padding: 16px;
        border-bottom: 1px solid #334155;
        background: #0f172a;
        font-size: 14px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        color: #94a3b8;
      }

      .panel-content {
        flex: 1;
        overflow-y: auto;
        padding: 16px;
      }

      .status-section {
        margin-bottom: 24px;
      }

      .status-section-title {
        font-size: 12px;
        font-weight: 700;
        color: #64748b;
        text-transform: uppercase;
        margin-bottom: 8px;
        letter-spacing: 0.5px;
      }

      .bot-status {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px;
        margin-bottom: 6px;
        background: #0f172a;
        border-radius: 6px;
        font-size: 13px;
      }

      .status-indicator {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        flex-shrink: 0;
      }

      .task-update {
        padding: 12px;
        margin-bottom: 8px;
        background: #0f172a;
        border-left: 3px solid #3b82f6;
        border-radius: 4px;
        font-size: 12px;
        line-height: 1.5;
      }

      .task-agent {
        font-weight: 600;
        color: #f1f5f9;
        margin-bottom: 4px;
      }

      .task-message {
        color: #cbd5e1;
      }

      .task-time {
        font-size: 10px;
        color: #64748b;
        margin-top: 4px;
      }

      .chat-panel {
        background: #1a1f35;
        display: flex;
        flex-direction: column;
        overflow: hidden;
      }

      .chat-messages {
        flex: 1;
        overflow-y: auto;
        padding: 16px;
        display: flex;
        flex-direction: column;
        gap: 12px;
      }

      .message {
        display: flex;
        animation: slideIn 0.3s ease-out;
      }

      .message.user {
        justify-content: flex-end;
      }

      .message-bubble {
        max-width: 90%;
        padding: 10px 14px;
        border-radius: 10px;
        word-wrap: break-word;
        font-size: 13px;
        line-height: 1.4;
      }

      .message.user .message-bubble {
        background: #3b82f6;
        color: #fff;
        border-bottom-right-radius: 2px;
      }

      .message.assistant .message-bubble {
        background: #334155;
        color: #e2e8f0;
        border-bottom-left-radius: 2px;
      }

      .chat-input-area {
        padding: 12px;
        border-top: 1px solid #334155;
        background: #0f172a;
        display: flex;
        gap: 8px;
      }

      .chat-input-area input {
        flex: 1;
        padding: 10px 12px;
        border: 1px solid #334155;
        border-radius: 6px;
        background: #1a1f35;
        color: #e2e8f0;
        font-size: 13px;
        outline: none;
        transition: border-color 0.2s;
      }

      .chat-input-area input:focus {
        border-color: #3b82f6;
      }

      .chat-input-area input::placeholder {
        color: #64748b;
      }

      .chat-input-area button {
        padding: 10px 16px;
        background: #3b82f6;
        border: none;
        border-radius: 6px;
        color: #fff;
        font-size: 12px;
        font-weight: 600;
        cursor: pointer;
        transition: background 0.2s;
      }

      .chat-input-area button:hover:not(:disabled) {
        background: #2563eb;
      }

      .chat-input-area button:disabled {
        background: #64748b;
        cursor: not-allowed;
        opacity: 0.5;
      }

      @keyframes slideIn {
        from {
          opacity: 0;
          transform: translateY(10px);
        }
        to {
          opacity: 1;
          transform: translateY(0);
        }
      }

      ::-webkit-scrollbar {
        width: 6px;
      }

      ::-webkit-scrollbar-track {
        background: #0f172a;
      }

      ::-webkit-scrollbar-thumb {
        background: #334155;
        border-radius: 3px;
      }

      ::-webkit-scrollbar-thumb:hover {
        background: #475569;
      }
    </style>
    """
  end

  @impl true
  def handle_event("update_message", %{"value" => msg}, socket) do
    {:noreply, assign(socket, current_message: msg)}
  end

  @impl true
  def handle_event("send_message", %{"key" => "Enter"}, socket) do
    send_chat_message(socket)
  end

  def handle_event("send_message", _params, socket) do
    send_chat_message(socket)
  end

  defp send_chat_message(%{assigns: %{current_message: "", loading: true}} = socket) do
    {:noreply, socket}
  end

  defp send_chat_message(%{assigns: %{current_message: message}} = socket) when message == "" do
    {:noreply, socket}
  end

  defp send_chat_message(socket) do
    message = socket.assigns.current_message

    {:noreply,
     socket
     |> assign(loading: true, current_message: "")
     |> stream_insert(:messages, %{id: :user_#{System.monotonic_time()}, role: "user", text: message})
     |> then(fn sock ->
       case ErgonSurfaceMentraGlassElixir.NATS.query_bridge(message) do
         {:ok, response} ->
           response_text = response["data"]["response"] || response["response"] || "No response"
           sock
           |> stream_insert(:messages, %{id: :assistant_#{System.monotonic_time()}, role: "assistant", text: response_text})
           |> assign(loading: false)

         {:error, reason} ->
           sock
           |> stream_insert(:messages, %{id: :error_#{System.monotonic_time()}, role: "assistant", text: "Error: #{reason}"})
           |> assign(loading: false)
       end
     |> push_event("scroll_to_bottom", %{})
     end)
    }
  end

  @impl true
  def handle_info({:task_update, update}, socket) do
    {:noreply,
     socket
     |> assign(task_updates: Enum.take([update | socket.assigns.task_updates], 10))}
  end

  defp subscribe_to_updates(socket) do
    if connected?(socket) do
      ErgonSurfaceMentraGlassElixir.NATS.subscribe_to_updates(self())
    end

    socket
  end

  defp status_color(status) when status in ["healthy", "ok"] do
    "background: #4ade80;"
  end

  defp status_color(_), do: "background: #64748b;"

  defp update_color(status) when status in ["success", "healthy"] do
    "border-left-color: #4ade80;"
  end

  defp update_color("error"), do: "border-left-color: #ef4444;"
  defp update_color("warning"), do: "border-left-color: #facc15;"
  defp update_color(_), do: "border-left-color: #3b82f6;"

  defp format_time(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> timestamp
    end
  end

  defp format_time(_), do: "now"
end
