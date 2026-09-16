defmodule ErgonSurfaceHudElixirWeb.Router do
  use ErgonSurfaceHudElixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ErgonSurfaceHudElixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ErgonSurfaceHudElixirWeb do
    pipe_through :browser

    live "/", OperationalLive
    live "/webview", OperationalLive
    live "/tabs", TabsLive
  end

  scope "/api", ErgonSurfaceHudElixirWeb do
    pipe_through :api

    get "/health", APIController, :health
    get "/debug", APIController, :debug
    get "/config", APIController, :config
    get "/certificate", APIController, :certificate
    get "/app.json", APIController, :app_json
  end

  # Bot API endpoints
  scope "/api/bots", ErgonSurfaceHudElixirWeb do
    pipe_through :api

    # Dashboard endpoints
    get "/status", BotDashboardController, :status
    get "/health", BotDashboardController, :health
    get "/list", BotDashboardController, :bots
    get "/updates", BotDashboardController, :updates

    # Chat endpoints
    post "/chat", BotChatController, :send_message
    get "/chat/query", BotChatController, :query
    get "/chat/history", BotChatController, :history

    # Control endpoints
    post "/restart", BotControlController, :restart_bot
    post "/reload", BotControlController, :reload_bot
    post "/refresh", BotControlController, :refresh_status
    post "/clear-cache", BotControlController, :clear_cache
    post "/execute", BotControlController, :execute_command

    # Events endpoints
    post "/events/update", BotEventsController, :post_update
    post "/events/subscribe", BotEventsController, :subscribe
    get "/events/health", BotEventsController, :health_check
  end

  # Fallback route for app.json and app_config.json at root level
  scope "/", ErgonSurfaceHudElixirWeb do
    pipe_through :api
    get "/app.json", APIController, :app_json
    get "/app_config.json", APIController, :app_config_json
  end
end
