defmodule ErgonSurfaceHudElixirWeb.FitnessHandheldLive do
  use ErgonSurfaceHudElixirWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       workouts: [],
       selected_index: 0,
       loading: true,
       logging: false,
       message: nil
     )
     |> fetch_recent_workouts()}
  end

  defp fetch_recent_workouts(socket) do
    Task.start_link(fn ->
      try do
        case Gnat.request(
               :hud_nats,
               "fitness.workout.list",
               Jason.encode!(%{payload: %{limit: 10}}),
               timeout: 5000
             ) do
          {:ok, %{body: body}} ->
            case Jason.decode(body) do
              {:ok, data} ->
                workouts = data["workouts"] || []
                send(self(), {:workouts_loaded, workouts})

              {:error, _} ->
                send(self(), {:workouts_loaded, []})
            end

          {:error, _} ->
            send(self(), {:workouts_loaded, []})
        end
      rescue
        _ -> send(self(), {:workouts_loaded, []})
      end
    end)

    socket
  end

  @impl true
  def handle_info({:workouts_loaded, workouts}, socket) do
    {:noreply,
     socket
     |> assign(workouts: workouts, loading: false)
     |> assign(message: if(Enum.empty?(workouts), do: "No workouts yet. Create one!", else: nil))}
  end

  @impl true
  def handle_info({:workout_logged, title}, socket) do
    {:noreply,
     socket
     |> assign(logging: false, message: "✓ Logged: #{title}")
     |> fetch_recent_workouts()}
  end

  @impl true
  def handle_info({:workout_log_failed, msg}, socket) do
    {:noreply, assign(socket, logging: false, message: "✗ #{msg}")}
  end

  @impl true
  def handle_event("gamepad-up", _params, socket) do
    index = max(socket.assigns.selected_index - 1, 0)
    {:noreply, assign(socket, selected_index: index, message: nil)}
  end

  @impl true
  def handle_event("gamepad-down", _params, socket) do
    count = length(socket.assigns.workouts)
    index = min(socket.assigns.selected_index + 1, count - 1)
    {:noreply, assign(socket, selected_index: index, message: nil)}
  end

  @impl true
  def handle_event("gamepad-confirm", _params, socket) do
    workouts = socket.assigns.workouts
    index = socket.assigns.selected_index

    case Enum.at(workouts, index) do
      nil ->
        {:noreply, assign(socket, message: "No workout selected")}

      workout ->
        {:noreply, log_workout(socket, workout)}
    end
  end

  defp log_workout(socket, workout) do
    Task.start_link(fn ->
      try do
        payload = %{
          exercise_type: workout["exercise_type"] || workout["title"],
          duration_minutes: workout["duration_minutes"] || 30,
          intensity: workout["intensity"] || "moderate"
        }

        case Gnat.request(:hud_nats, "fitness.set.log", Jason.encode!(%{payload: payload}),
               timeout: 5000
             ) do
          {:ok, _response} ->
            send(self(), {:workout_logged, workout["title"]})

          {:error, _} ->
            send(self(), {:workout_log_failed, "Failed to log workout"})
        end
      rescue
        _ -> send(self(), {:workout_log_failed, "Error logging workout"})
      end
    end)

    assign(socket, logging: true, message: "Logging...")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fitness-handheld">
      <div class="handheld-container">
        <%= if @loading do %>
          <div class="loading-state">
            <div class="spinner"></div>
            <p>Loading workouts...</p>
          </div>
        <% else %>
          <%= if Enum.empty?(@workouts) do %>
            <div class="empty-state">
              <div class="empty-icon">💪</div>
              <p>{@message || "No workouts yet"}</p>
              <p class="hint">Log your first workout!</p>
            </div>
          <% else %>
            <div class="workout-card">
              <%= for {workout, index} <- Enum.with_index(@workouts) do %>
                <%= if index == @selected_index do %>
                  <div class="current-workout">
                    <div class="workout-title">{workout["title"]}</div>
                    <div class="workout-details">
                      <div class="detail">
                        <span class="label">Type:</span>
                        <span class="value">{workout["exercise_type"]}</span>
                      </div>
                      <div class="detail">
                        <span class="label">Duration:</span>
                        <span class="value">{workout["duration_minutes"]} min</span>
                      </div>
                      <div class="detail">
                        <span class="label">Intensity:</span>
                        <span class="value">{workout["intensity"]}</span>
                      </div>
                      <div class="detail">
                        <span class="label">Date:</span>
                        <span class="value">{workout["date"]}</span>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>

              <div class="controls">
                <div class="control-hint">
                  <span class="key">↑ ↓</span>
                  <span class="action">Navigate</span>
                </div>
                <div class="control-hint">
                  <span class="key">A</span>
                  <span class="action">Log Workout</span>
                </div>
              </div>

              <%= if @message do %>
                <div class="message">{@message}</div>
              <% end %>

              <div class="counter">
                {@selected_index + 1} / {length(@workouts)}
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <script>
        document.addEventListener("DOMContentLoaded", function() {
          const liveSocket = window.liveSocket || {};
          let gamepadIndex = null;
          let lastPressed = {};

          function pollGamepad() {
            const gamepads = navigator.getGamepads();

            for (let i = 0; i < gamepads.length; i++) {
              const gp = gamepads[i];
              if (!gp) continue;

              gamepadIndex = i;

              // D-Pad: up (12), down (13)
              if (gp.buttons[12].pressed && !lastPressed[12]) {
                lastPressed[12] = true;
                const phxEvent = document.querySelector("[data-phx-main]");
                if (phxEvent && phxEvent.getAttribute("data-phx-session")) {
                  window.liveSocket?.exec("gamepad-up", {});
                }
              } else if (!gp.buttons[12].pressed) {
                lastPressed[12] = false;
              }

              if (gp.buttons[13].pressed && !lastPressed[13]) {
                lastPressed[13] = true;
                const phxEvent = document.querySelector("[data-phx-main]");
                if (phxEvent && phxEvent.getAttribute("data-phx-session")) {
                  window.liveSocket?.exec("gamepad-down", {});
                }
              } else if (!gp.buttons[13].pressed) {
                lastPressed[13] = false;
              }

              // A button (0)
              if (gp.buttons[0].pressed && !lastPressed[0]) {
                lastPressed[0] = true;
                const phxEvent = document.querySelector("[data-phx-main]");
                if (phxEvent && phxEvent.getAttribute("data-phx-session")) {
                  window.liveSocket?.exec("gamepad-confirm", {});
                }
              } else if (!gp.buttons[0].pressed) {
                lastPressed[0] = false;
              }
            }

            requestAnimationFrame(pollGamepad);
          }

          pollGamepad();
        });
      </script>

      <style>
        .fitness-handheld {
          display: flex;
          justify-content: center;
          align-items: center;
          min-height: 100vh;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          padding: 20px;
        }

        .handheld-container {
          width: 100%;
          max-width: 400px;
          background: #1a1a2e;
          border-radius: 20px;
          padding: 30px 20px;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
          color: #fff;
        }

        .loading-state,
        .empty-state {
          text-align: center;
          padding: 40px 20px;
        }

        .spinner {
          border: 4px solid #667eea;
          border-top: 4px solid transparent;
          border-radius: 50%;
          width: 50px;
          height: 50px;
          animation: spin 1s linear infinite;
          margin: 0 auto 20px;
        }

        @keyframes spin {
          to { transform: rotate(360deg); }
        }

        .empty-icon {
          font-size: 60px;
          margin-bottom: 20px;
        }

        .empty-state p {
          margin: 10px 0;
          font-size: 16px;
        }

        .empty-state .hint {
          color: #999;
          font-size: 14px;
        }

        .workout-card {
          background: #0f3460;
          border-radius: 15px;
          padding: 20px;
        }

        .current-workout {
          margin-bottom: 20px;
        }

        .workout-title {
          font-size: 24px;
          font-weight: bold;
          margin-bottom: 15px;
          color: #00d4ff;
        }

        .workout-details {
          background: rgba(0, 212, 255, 0.1);
          border-left: 3px solid #00d4ff;
          padding: 15px;
          border-radius: 8px;
          margin-bottom: 15px;
        }

        .detail {
          display: flex;
          justify-content: space-between;
          margin: 8px 0;
          font-size: 14px;
        }

        .detail .label {
          color: #999;
          font-weight: 600;
        }

        .detail .value {
          color: #00d4ff;
          font-weight: bold;
        }

        .controls {
          background: rgba(102, 126, 234, 0.2);
          border-radius: 10px;
          padding: 15px;
          margin-bottom: 15px;
        }

        .control-hint {
          display: flex;
          align-items: center;
          margin: 10px 0;
          font-size: 14px;
        }

        .control-hint .key {
          background: #667eea;
          color: #fff;
          padding: 5px 10px;
          border-radius: 5px;
          font-weight: bold;
          margin-right: 10px;
          min-width: 40px;
          text-align: center;
          font-size: 12px;
        }

        .control-hint .action {
          color: #ccc;
        }

        .message {
          background: rgba(0, 212, 255, 0.2);
          color: #00d4ff;
          padding: 10px;
          border-radius: 8px;
          text-align: center;
          font-size: 14px;
          margin-bottom: 10px;
        }

        .counter {
          text-align: center;
          color: #667eea;
          font-size: 12px;
          font-weight: bold;
        }
      </style>
    </div>
    """
  end
end
