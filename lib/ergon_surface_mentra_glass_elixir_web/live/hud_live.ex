defmodule ErgonSurfaceHudElixirWeb.HUDLive do
  use ErgonSurfaceHudElixirWeb, :live_view

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
       task_updates: [],
       fitness_signal: nil,
       gtd_signal: nil,
       active_modal: nil,
       fitness_tasks: [],
       gtd_tasks: %{blocked: [], due: []}
     )
     |> subscribe_to_updates()
     |> fetch_fitness_data()
     |> fetch_gtd_data()}
  end

  defp fetch_fitness_data(socket) do
    Task.start_link(fn ->
      try do
        case Gnat.request(:hud_nats, "fitness.status", "{}", timeout: 5000) do
          {:ok, %{body: body}} ->
            case Jason.decode(body) do
              {:ok, data} ->
                signal = data["has_upcoming"] || false

                send(
                  self(),
                  {:fitness_update,
                   %{signal: signal, message: data["message"] || "Time to work out!"}}
                )

              {:error, _} ->
                send(self(), {:fitness_update, %{signal: false, message: nil}})
            end

          {:error, _} ->
            send(self(), {:fitness_update, %{signal: false, message: nil}})
        end
      rescue
        _ -> send(self(), {:fitness_update, %{signal: false, message: nil}})
      end
    end)

    socket
  end

  defp fetch_gtd_data(socket) do
    Task.start_link(fn ->
      try do
        case Gnat.request(:hud_nats, "gtd.task.list", Jason.encode!(%{filter: "status"}),
               timeout: 5000
             ) do
          {:ok, %{body: body}} ->
            case Jason.decode(body) do
              {:ok, data} ->
                tasks = data["tasks"] || []

                blocked =
                  Enum.filter(tasks, &(&1["status"] == "blocked")) |> Enum.map(&format_task/1)

                due = Enum.filter(tasks, &(&1["status"] == "due")) |> Enum.map(&format_task/1)
                send(self(), {:gtd_update, %{blocked: blocked, due: due}})

              {:error, _} ->
                send(self(), {:gtd_update, %{blocked: [], due: []}})
            end

          {:error, _} ->
            send(self(), {:gtd_update, %{blocked: [], due: []}})
        end
      rescue
        _ -> send(self(), {:gtd_update, %{blocked: [], due: []}})
      end
    end)

    socket
  end

  defp format_task(task) do
    %{
      id: task["id"] || task["title"],
      title: task["title"],
      time: task["time_label"] || "no due date"
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="hud">
      <!-- Status Bar -->
      <div class="status-bar">
        <button
          phx-click="show-modal"
          phx-value-modal="fitness"
          class={["status-bar-button", if(@fitness_signal, do: "active", else: "")]}
        >
          <span class="icon">🏃</span>
          <span class="label">{if @fitness_signal, do: "Work out?", else: ""}</span>
        </button>

        <button
          phx-click="show-modal"
          phx-value-modal="gtd"
          class={["status-bar-button", if(@gtd_signal, do: "active", else: "")]}
        >
          <span class="icon">📋</span>
          <span class="label">{if @gtd_signal, do: "Tasks", else: ""}</span>
        </button>

        <div class="status-bar-spacer"></div>
        <span class="status-bar-time">{DateTime.utc_now() |> Calendar.strftime("%H:%M")}</span>
      </div>
      
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
                  <span class="bot-name">{key}</span>
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
                  <div class="task-agent">{update.agent}</div>
                  <div class="task-message">{update.message}</div>
                  <div class="task-time">{format_time(update.timestamp)}</div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Fitness Modal -->
      <%= if @active_modal == "fitness" do %>
        <div class="modal-overlay" phx-click="close-modal">
          <div class="modal-content" phx-click="stop-propagation">
            <div class="modal-header">
              <h3>Log Workout</h3>
              <button class="modal-close" phx-click="close-modal">×</button>
            </div>
            <form phx-submit="log-workout" class="modal-form">
              <div class="form-group">
                <label>Type</label>
                <input type="text" name="workout_type" placeholder="e.g. run, lift, yoga" required />
              </div>
              <div class="form-group">
                <label>Duration (min)</label>
                <input type="number" name="duration" placeholder="30" min="1" required />
              </div>
              <div class="form-group">
                <label>Notes</label>
                <textarea name="notes" placeholder="How did it feel?" rows="3"></textarea>
              </div>
              <button type="submit" class="modal-submit">Log It</button>
            </form>
          </div>
        </div>
      <% end %>
      
    <!-- GTD Modal -->
      <%= if @active_modal == "gtd" do %>
        <div class="modal-overlay" phx-click="close-modal">
          <div class="modal-content" phx-click="stop-propagation">
            <div class="modal-header">
              <h3>Tasks</h3>
              <button class="modal-close" phx-click="close-modal">×</button>
            </div>
            <div class="gtd-modal-body">
              <div class="task-section">
                <h4 class="section-title">🚫 Blocked</h4>
                <div class="task-list">
                  <%= if Enum.empty?(@gtd_tasks.blocked) do %>
                    <div class="task-item empty">No blocked tasks</div>
                  <% else %>
                    <%= for task <- @gtd_tasks.blocked do %>
                      <div class="task-item">
                        <span class="task-title">{task.title}</span>
                        <span class="task-meta">{task.time}</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>

              <div class="task-section">
                <h4 class="section-title">📅 Due Soon</h4>
                <div class="task-list">
                  <%= if Enum.empty?(@gtd_tasks.due) do %>
                    <div class="task-item empty">No due tasks</div>
                  <% else %>
                    <%= for task <- @gtd_tasks.due do %>
                      <div
                        class="task-item clickable"
                        phx-click="work-on-task"
                        phx-value-task={task.id || task.title}
                      >
                        <span class="task-title">{task.title}</span>
                        <span class="task-meta">{task.time}</span>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Chat Panel -->
      <div class="chat-panel">
        <div class="panel-header">Assistant</div>
        <div class="chat-messages" id="messages" phx-update="stream">
          <%= for {_id, message} <- @messages do %>
            <div class={"message #{message.role}"}>
              <div class="message-bubble">{message.text}</div>
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
            {if @loading, do: "...", else: "Send"}
          </button>
        </div>
      </div>
    </div>

    <style>
      .hud {
        width: 100%;
        height: 100vh;
        display: grid;
        grid-template-rows: auto 1fr;
        grid-template-columns: 1.5fr 1fr;
        gap: 1px;
        background: #0f172a;
        padding: 1px;
      }

      .status-bar {
        grid-column: 1 / -1;
        background: #1a2332;
        border-bottom: 1px solid #3b82f6;
        padding: 8px 16px;
        display: flex;
        align-items: center;
        gap: 12px;
      }

      .status-bar-button {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 4px 12px;
        background: transparent;
        border: none;
        border-radius: 4px;
        color: #64748b;
        cursor: pointer;
        font-size: 12px;
        transition: all 0.2s ease;
      }

      .status-bar-button:hover {
        color: #94a3b8;
      }

      .status-bar-button.active {
        background: rgba(34, 197, 94, 0.2);
        color: #86efac;
        border: 1px solid #22c55e;
      }

      .status-bar-button .icon {
        font-size: 16px;
      }

      .status-bar-button .label {
        font-size: 11px;
        font-weight: 500;
      }

      .status-bar-spacer {
        flex: 1;
      }

      .status-bar-time {
        font-size: 11px;
        color: #64748b;
      }

      .modal-overlay {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: rgba(0, 0, 0, 0.7);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
      }

      .modal-content {
        background: #1a2332;
        border: 1px solid #3b82f6;
        border-radius: 8px;
        padding: 24px;
        max-width: 400px;
        width: 90%;
        box-shadow: 0 20px 25px rgba(0, 0, 0, 0.5);
      }

      .modal-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 20px;
        border-bottom: 1px solid #334155;
        padding-bottom: 12px;
      }

      .modal-header h3 {
        margin: 0;
        font-size: 18px;
        font-weight: 600;
        color: #e2e8f0;
      }

      .modal-close {
        background: none;
        border: none;
        color: #94a3b8;
        font-size: 24px;
        cursor: pointer;
        padding: 0;
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .modal-close:hover {
        color: #cbd5e1;
      }

      .modal-form {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }

      .form-group {
        display: flex;
        flex-direction: column;
        gap: 6px;
      }

      .form-group label {
        font-size: 12px;
        font-weight: 600;
        color: #94a3b8;
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }

      .form-group input,
      .form-group textarea {
        background: #0f172a;
        border: 1px solid #334155;
        border-radius: 4px;
        color: #e2e8f0;
        padding: 8px 12px;
        font-family: inherit;
        font-size: 14px;
      }

      .form-group input:focus,
      .form-group textarea:focus {
        outline: none;
        border-color: #3b82f6;
        background: #1a2332;
      }

      .modal-submit {
        background: #3b82f6;
        color: white;
        border: none;
        border-radius: 4px;
        padding: 10px 16px;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
        transition: all 0.2s ease;
        margin-top: 8px;
      }

      .modal-submit:hover {
        background: #2563eb;
      }

      .gtd-modal-body {
        display: flex;
        flex-direction: column;
        gap: 20px;
        max-height: 500px;
        overflow-y: auto;
      }

      .task-section {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }

      .section-title {
        margin: 0;
        font-size: 12px;
        font-weight: 700;
        color: #94a3b8;
        text-transform: uppercase;
        letter-spacing: 0.5px;
      }

      .task-list {
        display: flex;
        flex-direction: column;
        gap: 8px;
      }

      .task-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 8px 12px;
        background: #0f172a;
        border-left: 2px solid #334155;
        border-radius: 2px;
        font-size: 13px;
      }

      .task-item.clickable {
        border-left-color: #3b82f6;
        cursor: pointer;
        transition: all 0.2s ease;
      }

      .task-item.clickable:hover {
        background: #1a2332;
        border-left-color: #60a5fa;
      }

      .task-title {
        color: #e2e8f0;
        font-weight: 500;
      }

      .task-meta {
        color: #64748b;
        font-size: 11px;
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

  def handle_event("show-modal", %{"modal" => modal_type}, socket) do
    {:noreply, assign(socket, :active_modal, modal_type)}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, assign(socket, :active_modal, nil)}
  end

  def handle_event("stop-propagation", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "log-workout",
        %{"workout_type" => type, "duration" => duration, "notes" => notes},
        socket
      ) do
    Task.start_link(fn ->
      send_workout_log(type, duration, notes)
    end)

    # Close modal and show confirmation
    socket
    |> assign(:active_modal, nil)
    |> assign(:fitness_signal, nil)
    |> then(&{:noreply, &1})
  end

  def handle_event("work-on-task", %{"task" => task_id}, socket) do
    Task.start_link(fn ->
      send_gtd_task_start(task_id)
    end)

    # Close modal and focus on task
    {:noreply, assign(socket, :active_modal, nil)}
  end

  defp send_workout_log(type, duration, notes) do
    try do
      body =
        Jason.encode!(%{
          "event_id" => Ecto.UUID.generate(),
          "event" => "fitness.workout.log",
          "schema_version" => "1.0",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "source" => "hud_surface",
          "source_node" => "hud@localhost",
          "triggered_by" => "hud_surface.user",
          "payload" => %{
            "workout_type" => type,
            "duration_minutes" => String.to_integer(duration),
            "notes" => notes
          }
        })

      case Gnat.request(:hud_nats, "fitness.workout.log", body, timeout: 5000) do
        {:ok, _response} ->
          Logger.info("Workout logged successfully")

        {:error, reason} ->
          Logger.warning("Failed to log workout: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Error logging workout: #{inspect(e)}")
    end
  end

  defp send_gtd_task_start(task_id) do
    try do
      body =
        Jason.encode!(%{
          "event_id" => Ecto.UUID.generate(),
          "event" => "gtd.task.work_on",
          "schema_version" => "1.0",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "source" => "hud_surface",
          "source_node" => "hud@localhost",
          "triggered_by" => "hud_surface.user",
          "payload" => %{
            "task_id" => task_id
          }
        })

      case Gnat.request(:hud_nats, "gtd.task.work_on", body, timeout: 5000) do
        {:ok, response} ->
          case Jason.decode(response.body) do
            {:ok, data} ->
              Logger.info("Task started: #{data["title"]}")

            {:error, _} ->
              Logger.info("Task started: #{task_id}")
          end

        {:error, reason} ->
          Logger.warning("Failed to start task: #{inspect(reason)}")
      end
    rescue
      e ->
        Logger.error("Error starting task: #{inspect(e)}")
    end
  end

  @impl true
  def handle_info({:fitness_update, data}, socket) do
    {:noreply,
     socket
     |> assign(:fitness_signal, data.message)
     |> assign(:fitness_tasks, [data])}
  end

  def handle_info({:gtd_update, data}, socket) do
    {:noreply,
     socket
     |> assign(:gtd_signal, "#{Enum.count(data.due)} due")
     |> assign(:gtd_tasks, data)}
  end

  def handle_info({:task_update, update}, socket) do
    {:noreply,
     socket
     |> assign(task_updates: Enum.take([update | socket.assigns.task_updates], 10))}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp send_chat_message(%{assigns: %{current_message: "", loading: true}} = socket) do
    {:noreply, socket}
  end

  defp send_chat_message(%{assigns: %{current_message: message}} = socket) when message == "" do
    {:noreply, socket}
  end

  defp send_chat_message(socket) do
    message = socket.assigns.current_message
    user_msg_id = "user_#{System.monotonic_time()}"

    socket =
      socket
      |> assign(loading: true, current_message: "")
      |> stream_insert(:messages, %{id: user_msg_id, role: "user", text: message})

    case ErgonSurfaceHudElixir.NATS.query_bridge(message) do
      {:ok, response} ->
        response_text = response["data"]["response"] || response["response"] || "No response"
        assistant_msg_id = "assistant_#{System.monotonic_time()}"

        {:noreply,
         socket
         |> stream_insert(:messages, %{
           id: assistant_msg_id,
           role: "assistant",
           text: response_text
         })
         |> assign(loading: false)
         |> push_event("scroll_to_bottom", %{})}

      {:error, reason} ->
        error_msg_id = "error_#{System.monotonic_time()}"

        {:noreply,
         socket
         |> stream_insert(:messages, %{
           id: error_msg_id,
           role: "assistant",
           text: "Error: #{reason}"
         })
         |> assign(loading: false)
         |> push_event("scroll_to_bottom", %{})}
    end
  end

  defp subscribe_to_updates(socket) do
    if connected?(socket) do
      ErgonSurfaceHudElixir.NATS.subscribe_to_updates(self())
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
