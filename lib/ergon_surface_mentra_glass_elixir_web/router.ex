defmodule ErgonSurfaceMentraGlassElixirWeb.Router do
  use ErgonSurfaceMentraGlassElixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ErgonSurfaceMentraGlassElixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ErgonSurfaceMentraGlassElixirWeb do
    pipe_through :browser

    live "/", HUDLive
  end

  scope "/api", ErgonSurfaceMentraGlassElixirWeb do
    pipe_through :api

    get "/health", APIController, :health
    get "/debug", APIController, :debug
    get "/app.json", APIController, :app_json
  end

  # Fallback route for app.json at root level
  scope "/", ErgonSurfaceMentraGlassElixirWeb do
    pipe_through :api
    get "/app.json", APIController, :app_json
  end
end
