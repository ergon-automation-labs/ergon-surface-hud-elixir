defmodule ErgonSurfaceHudElixirWeb.OperationalLive do
  use ErgonSurfaceHudElixirWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Start the rotation timer
    if connected?(socket) do
      Process.send_after(self(), :rotate_activity, 1000)
    end

    {:ok,
     socket
     |> assign(
       # Current view/tab
       active_tab: :operational,
       # Activity rotation
       current_activity_index: 0,
       activity_cycle: [
         {:fitness, "💪 Fitness", 600},
         {:rest, "⏸️ Rest", 300},
         {:chores, "🧹 Chores", 600},
         {:rest, "⏸️ Rest", 300},
         {:wife_care, "👰 Wife Care", 600},
         {:rest, "⏸️ Rest", 300}
       ],
       activity_timer: 0,
       # Content data
       current_activity: nil,
       fitness_suggestions: [],
       chore_suggestions: [],
       wife_care_suggestions: [],
       task_context: [],
       messages: [],
       current_message: "",
       loading: false,
       notifications: [],
       # Metrics
       productivity_score: 87,
       active_bots: 12,
       system_health: "healthy",
       metric_index: 0,
       metrics: [
         {"Productivity", "87%"},
         {"Tasks Active", "12"},
         {"Bots Online", "8/8"},
         {"System Health", "Healthy"}
       ]
     )
     |> load_activities()
     |> subscribe_to_updates()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="operational-interface">
      <!-- Marquee/Metrics Bar -->
      <div class="marquee-bar">
        <div class="marquee-content">
          <span class="marquee-icon">🤖</span>
          <span class="marquee-label">Bot Army</span>
          <span class="marquee-separator desktop-only">|</span>
          
    <!-- Mobile Activity Info -->
          <span class="mobile-activity-info">
            <%= if @current_activity do %>
              <span>{@current_activity.emoji}</span>
              <span>{String.slice(@current_activity.title, 0..15)}</span>
            <% end %>
          </span>
          
    <!-- Desktop Metrics -->
          <span class="marquee-separator desktop-only">|</span>
          <%= for {label, value} <- Enum.slice(@metrics, @metric_index, 1) do %>
            <span class="marquee-metric desktop-only">{label}: <strong>{value}</strong></span>
          <% end %>
          <span class="marquee-separator desktop-only">|</span>
          <button class="marquee-cycle desktop-only" phx-click="cycle_metric" title="Cycle metrics">
            ↻
          </button>
        </div>
      </div>
      
    <!-- Main Interface -->
      <div class="main-grid">
        <!-- Left: Activity Sidebar -->
        <div class="activity-sidebar">
          <.activity_card
            activity={@current_activity}
            activity_type={current_activity_type(@activity_cycle, @current_activity_index)}
            timer={@activity_timer}
            duration={current_activity_duration(@activity_cycle, @current_activity_index)}
          />
        </div>
        
    <!-- Right: Content Area (split context/chat) -->
        <div class="content-area">
          <!-- Top: Task Context -->
          <div class="task-context-panel">
            <div class="panel-header">📋 Task Context</div>
            <div class="context-content">
              <.task_context_display tasks={@task_context} />
            </div>
          </div>
          
    <!-- Bottom: Chat -->
          <div class="chat-panel">
            <div class="panel-header">💬 Chat</div>
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
                placeholder="Ask..."
                value={@current_message}
                phx-keydown="send_message"
                phx-change="update_message"
                autocomplete="off"
              />
              <button phx-click="send_message" disabled={@loading}>
                {if @loading, do: "...", else: "→"}
              </button>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Bottom: Secondary Tabs -->
      <div class="secondary-tabs">
        <button
          class={"tab-btn #{if @active_tab == :operational, do: "active"}"}
          phx-click="select_tab"
          phx-value-tab="operational"
        >
          🎮 Operational
        </button>
        <button
          class={"tab-btn #{if @active_tab == :notifications, do: "active"}"}
          phx-click="select_tab"
          phx-value-tab="notifications"
        >
          🔔 Notifications
        </button>
        <button
          class={"tab-btn #{if @active_tab == :dashboard, do: "active"}"}
          phx-click="select_tab"
          phx-value-tab="dashboard"
        >
          📊 Dashboard
        </button>
        <button
          class={"tab-btn #{if @active_tab == :control, do: "active"}"}
          phx-click="select_tab"
          phx-value-tab="control"
        >
          ⚙️ Control
        </button>
      </div>
      
    <!-- Notifications Tab Content -->
      <%= if @active_tab == :notifications do %>
        <div class="tab-content notifications-tab">
          <div class="notifications-header">
            <h2>Bot Notifications</h2>
            <%= if Enum.empty?(@notifications) do %>
              <p class="no-notifications">No messages yet</p>
            <% else %>
              <div class="notifications-list">
                <%= for notification <- Enum.reverse(@notifications) do %>
                  <div class="notification-item">
                    <div class="notification-time">{notification.timestamp}</div>
                    <div class="notification-source">{notification.source}</div>
                    <div class="notification-message">{notification.message}</div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
            "Helvetica Neue", Arial, sans-serif;
          background: #0a0e27;
          color: #e2e8f0;
          height: 100vh;
          overflow: hidden;
        }

        .operational-interface {
          width: 100%;
          height: 100vh;
          display: flex;
          flex-direction: column;
          background: linear-gradient(135deg, #0f172a 0%, #1a1f35 100%);
        }

        /* Marquee Bar */
        .marquee-bar {
          background: linear-gradient(90deg, #1a1f35 0%, #2d3748 50%, #1a1f35 100%);
          border-bottom: 2px solid #3b82f6;
          padding: 12px 16px;
          font-size: 14px;
          font-weight: 600;
          color: #e2e8f0;
          display: flex;
          align-items: center;
          gap: 8px;
          flex-shrink: 0;
        }

        .marquee-content {
          display: flex;
          align-items: center;
          gap: 12px;
          width: 100%;
        }

        .marquee-icon {
          font-size: 18px;
          animation: pulse 2s infinite;
        }

        .marquee-label {
          text-transform: uppercase;
          letter-spacing: 1px;
          color: #3b82f6;
        }

        .marquee-separator {
          color: #475569;
        }

        .marquee-metric {
          color: #cbd5e1;
          flex: 1;
        }

        .marquee-metric strong {
          color: #3b82f6;
        }

        .marquee-cycle {
          padding: 6px 12px;
          background: rgba(59, 130, 246, 0.1);
          border: 1px solid #3b82f6;
          color: #3b82f6;
          border-radius: 4px;
          cursor: pointer;
          font-size: 12px;
          font-weight: 600;
          transition: all 0.2s;
        }

        .marquee-cycle:active {
          background: #3b82f6;
          color: #fff;
        }

        .desktop-only {
          display: flex;
          align-items: center;
        }

        .mobile-activity-info {
          display: none;
          align-items: center;
          gap: 6px;
          font-size: 12px;
          font-weight: 600;
          color: #e2e8f0;
        }

        @keyframes pulse {
          0%,
          100% {
            opacity: 1;
          }
          50% {
            opacity: 0.6;
          }
        }

        /* Main Grid */
        .main-grid {
          flex: 1;
          display: grid;
          grid-template-columns: 180px 1fr;
          gap: 1px;
          padding: 1px;
          background: #0f172a;
          overflow: hidden;
        }

        /* Activity Sidebar */
        .activity-sidebar {
          background: #1a1f35;
          border-right: 1px solid #334155;
          padding: 16px;
          overflow-y: auto;
          display: flex;
          flex-direction: column;
          align-items: center;
        }

        /* Content Area - splits context and chat vertically (top and bottom) */
        .content-area {
          display: grid;
          grid-template-rows: 1fr 1fr;
          gap: 1px;
          background: #0f172a;
          overflow: hidden;
        }

        /* Task Context Panel */
        .task-context-panel {
          background: #1a1f35;
          display: flex;
          flex-direction: column;
          overflow: hidden;
          border-bottom: 1px solid #334155;
        }

        .panel-header {
          padding: 12px 16px;
          border-bottom: 1px solid #334155;
          background: #0f172a;
          font-size: 13px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.5px;
          color: #94a3b8;
        }

        .context-content {
          flex: 1;
          overflow-y: auto;
          padding: 16px;
        }

        /* Chat Panel */
        .chat-panel {
          background: #1a1f35;
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }

        .chat-messages {
          flex: 1;
          overflow-y: auto;
          padding: 12px;
          display: flex;
          flex-direction: column;
          gap: 8px;
        }

        .message {
          display: flex;
          animation: slideIn 0.3s ease-out;
        }

        .message.user {
          justify-content: flex-end;
        }

        .message-bubble {
          max-width: 85%;
          padding: 8px 12px;
          border-radius: 8px;
          word-wrap: break-word;
          font-size: 12px;
          line-height: 1.4;
        }

        .message.user .message-bubble {
          background: #3b82f6;
          color: #fff;
        }

        .message.assistant .message-bubble {
          background: #334155;
          color: #e2e8f0;
        }

        .chat-input-area {
          padding: 10px;
          border-top: 1px solid #334155;
          background: #0f172a;
          display: flex;
          gap: 6px;
          flex-shrink: 0;
        }

        .chat-input-area input {
          flex: 1;
          padding: 8px 10px;
          border: 1px solid #334155;
          border-radius: 4px;
          background: #1a1f35;
          color: #e2e8f0;
          font-size: 12px;
          outline: none;
        }

        .chat-input-area input:focus {
          border-color: #3b82f6;
        }

        .chat-input-area button {
          padding: 8px 12px;
          background: #3b82f6;
          border: none;
          border-radius: 4px;
          color: #fff;
          font-size: 14px;
          cursor: pointer;
          transition: background 0.2s;
        }

        .chat-input-area button:active:not(:disabled) {
          background: #2563eb;
        }

        .chat-input-area button:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }

        /* Secondary Tabs */
        .secondary-tabs {
          display: flex;
          gap: 0;
          background: #0f172a;
          border-top: 1px solid #334155;
          flex-shrink: 0;
        }

        .tab-btn {
          flex: 1;
          padding: 10px;
          border: none;
          background: transparent;
          color: #94a3b8;
          font-size: 12px;
          font-weight: 600;
          cursor: pointer;
          transition: all 0.2s;
          border-top: 2px solid transparent;
        }

        .tab-btn:active {
          background: rgba(255, 255, 255, 0.05);
        }

        .tab-btn.active {
          color: #3b82f6;
          border-top-color: #3b82f6;
        }

        /* Scrollbars */
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

        /* Mobile Responsive Layout */
        @media (max-width: 768px) {
          .desktop-only {
            display: none !important;
          }

          .mobile-activity-info {
            display: flex !important;
          }

          .main-grid {
            grid-template-columns: 1fr;
          }

          /* Hide sidebar on mobile, show abbreviated in marquee */
          .activity-sidebar {
            display: none;
          }

          /* Keep context and chat stacked vertically on mobile */
          .content-area {
            grid-template-rows: 1fr 1fr;
          }

          .task-context-panel {
            border-right: none;
            border-bottom: 1px solid #334155;
          }

          .panel-header {
            font-size: 12px;
            padding: 8px 12px;
          }

          .context-content {
            padding: 12px;
            font-size: 12px;
          }

          .chat-messages {
            padding: 8px;
          }

          .chat-input-area {
            padding: 8px;
            gap: 4px;
          }

          .chat-input-area input {
            padding: 6px 8px;
            font-size: 12px;
          }

          .chat-input-area button {
            padding: 6px 10px;
            font-size: 12px;
          }

          .marquee-bar {
            padding: 10px 12px;
            font-size: 11px;
            flex-wrap: wrap;
          }

          .marquee-icon {
            font-size: 16px;
          }

          .marquee-content {
            flex-wrap: wrap;
            gap: 8px;
            width: 100%;
          }

          .message-bubble {
            font-size: 11px;
            padding: 6px 10px;
          }
        }

        /* Phone Portrait (very small) */
        @media (max-width: 480px) {
          .marquee-label {
            display: none;
          }

          .marquee-separator {
            display: none;
          }

          .marquee-content {
            gap: 6px;
          }

          .marquee-metric {
            font-size: 10px;
          }

          .tab-btn {
            font-size: 11px;
            padding: 8px;
          }

          .panel-header {
            font-size: 11px;
            padding: 6px 10px;
          }

          .marquee-cycle {
            font-size: 10px;
            padding: 4px 8px;
          }
        }

        /* Tab Content */
        .tab-content {
          display: none;
          flex: 1;
          overflow: hidden;
          background: #1a1f35;
        }

        .tab-content.active {
          display: flex;
        }

        /* Notifications Tab */
        .notifications-tab {
          flex-direction: column;
          padding: 16px;
        }

        .notifications-header {
          flex: 1;
          overflow-y: auto;
          display: flex;
          flex-direction: column;
        }

        .notifications-header h2 {
          font-size: 14px;
          margin-bottom: 12px;
          color: #3b82f6;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }

        .no-notifications {
          color: #94a3b8;
          text-align: center;
          padding: 32px 16px;
          font-size: 13px;
        }

        .notifications-list {
          display: flex;
          flex-direction: column;
          gap: 12px;
        }

        .notification-item {
          padding: 12px;
          background: #0f172a;
          border-left: 3px solid #3b82f6;
          border-radius: 4px;
          font-size: 12px;
        }

        .notification-time {
          color: #64748b;
          font-size: 10px;
          margin-bottom: 4px;
        }

        .notification-source {
          color: #3b82f6;
          font-weight: 600;
          margin-bottom: 6px;
        }

        .notification-message {
          color: #cbd5e1;
          line-height: 1.5;
        }
      </style>
    </div>
    """
  end

  attr :activity, :map, required: true
  attr :activity_type, :atom, required: true
  attr :timer, :integer, required: true
  attr :duration, :integer, required: true

  defp activity_card(%{activity: nil} = assigns) do
    ~H"""
    <div class="activity-card loading">
      <div class="activity-placeholder">Loading...</div>
    </div>
    """
  end

  defp activity_card(assigns) do
    progress_percent =
      if assigns.duration > 0, do: round(assigns.timer / assigns.duration * 100), else: 0

    ~H"""
    <div class="activity-card" style={activity_card_style(@activity_type)}>
      <div class="activity-emoji">{@activity.emoji}</div>
      <div class="activity-title">{@activity.title}</div>
      <div class="activity-description">{@activity.description}</div>

      <div class="activity-progress">
        <div class="progress-bar">
          <div class="progress-fill" style={"width: #{progress_percent}%"}></div>
        </div>
        <div class="timer">
          {format_time(@timer)}
        </div>
      </div>

      <button class="activity-done" phx-click="mark_activity_done">
        ✓ Done
      </button>

      <div class="next-preview">
        Next activity coming up...
      </div>
    </div>
    """
  end

  defp activity_card_style(:fitness),
    do: "background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);"

  defp activity_card_style(:chores),
    do: "background: linear-gradient(135deg, #8b5cf6 0%, #6d28d9 100%);"

  defp activity_card_style(:wife_care),
    do: "background: linear-gradient(135deg, #ec4899 0%, #be185d 100%);"

  defp activity_card_style(:rest),
    do: "background: linear-gradient(135deg, #3b82f6 0%, #1e40af 100%);"

  defp task_context_display(%{tasks: []} = assigns) do
    ~H"""
    <div class="empty-state">
      <p>No active tasks</p>
    </div>
    """
  end

  defp task_context_display(assigns) do
    ~H"""
    <div class="task-list">
      <%= for task <- @tasks do %>
        <div class="task-item">
          <div class="task-name">{task.name}</div>
          <div class="task-progress">{task.progress}%</div>
          <div class="task-bar">
            <div class="task-fill" style={"width: #{task.progress}%"}></div>
          </div>
          <div class="task-bots">
            <%= for bot <- task.bots do %>
              <span class="bot-tag">{bot}</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: String.to_atom(tab))}
  end

  def handle_event("cycle_metric", _params, socket) do
    new_index = rem(socket.assigns.metric_index + 1, length(socket.assigns.metrics))
    {:noreply, assign(socket, metric_index: new_index)}
  end

  def handle_event("mark_activity_done", _params, socket) do
    # Advance to next activity
    new_index =
      rem(socket.assigns.current_activity_index + 1, length(socket.assigns.activity_cycle))

    {:noreply,
     socket |> assign(current_activity_index: new_index, activity_timer: 0) |> load_activities()}
  end

  def handle_event("update_message", %{"value" => msg}, socket) do
    {:noreply, assign(socket, current_message: msg)}
  end

  def handle_event("send_message", %{"key" => "Enter"}, socket) do
    send_chat_message(socket)
  end

  def handle_event("send_message", _params, socket) do
    send_chat_message(socket)
  end

  @impl true
  def handle_info(:rotate_activity, socket) do
    new_timer = socket.assigns.activity_timer + 1

    current_duration =
      current_activity_duration(
        socket.assigns.activity_cycle,
        socket.assigns.current_activity_index
      )

    {new_index, new_timer} =
      if new_timer >= current_duration do
        {rem(socket.assigns.current_activity_index + 1, length(socket.assigns.activity_cycle)), 0}
      else
        {socket.assigns.current_activity_index, new_timer}
      end

    socket =
      socket
      |> assign(current_activity_index: new_index, activity_timer: new_timer)
      |> load_activities()

    Process.send_after(self(), :rotate_activity, 1000)
    {:noreply, socket}
  end

  def handle_info({:task_update, _update}, socket) do
    {:noreply, socket}
  end

  def handle_info({:notification, notification}, socket) do
    {:noreply, assign(socket, notifications: [notification | socket.assigns.notifications])}
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
         |> assign(loading: false)}

      {:error, reason} ->
        error_msg_id = "error_#{System.monotonic_time()}"

        {:noreply,
         socket
         |> stream_insert(:messages, %{
           id: error_msg_id,
           role: "assistant",
           text: "Error: #{reason}"
         })
         |> assign(loading: false)}
    end
  end

  defp load_activities(socket) do
    index = socket.assigns.current_activity_index
    activity_type = current_activity_type(socket.assigns.activity_cycle, index)

    # Fetch real activity data from bots
    activity = fetch_activity_data(activity_type)

    # Fetch real task context
    task_context = ErgonSurfaceHudElixir.Services.ActivityService.get_active_tasks()

    assign(socket, current_activity: activity, task_context: task_context)
  end

  defp fetch_activity_data(:fitness) do
    ErgonSurfaceHudElixir.Services.ActivityService.get_fitness_suggestions()
    |> Enum.random()
  rescue
    _ -> mock_activity(:fitness)
  end

  defp fetch_activity_data(:chores) do
    ErgonSurfaceHudElixir.Services.ActivityService.get_chore_suggestions()
    |> Enum.random()
  rescue
    _ -> mock_activity(:chores)
  end

  defp fetch_activity_data(:wife_care) do
    ErgonSurfaceHudElixir.Services.ActivityService.get_wife_care_suggestions()
    |> Enum.random()
  rescue
    _ -> mock_activity(:wife_care)
  end

  defp fetch_activity_data(:rest) do
    mock_activity(:rest)
  end

  defp mock_activity(:fitness) do
    %{
      emoji: "💪",
      title: "Push-ups",
      description: "3 sets of 15 reps"
    }
  end

  defp mock_activity(:chores) do
    %{
      emoji: "🧹",
      title: "Clean desk",
      description: "Organize workspace"
    }
  end

  defp mock_activity(:wife_care) do
    %{
      emoji: "👰",
      title: "Plan dinner",
      description: "Cook together"
    }
  end

  defp mock_activity(:rest) do
    %{
      emoji: "⏸️",
      title: "Recovery time",
      description: "Hydrate & breathe"
    }
  end

  defp current_activity_type(cycle, index) do
    elem(Enum.at(cycle, index), 0)
  end

  defp current_activity_duration(cycle, index) do
    elem(Enum.at(cycle, index), 2)
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end

  defp subscribe_to_updates(socket) do
    if connected?(socket) do
      ErgonSurfaceHudElixir.NATS.subscribe_to_updates(self())
    end

    socket
  end
end
