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

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ErgonSurfaceMentraGlassElixirWeb do
  #   pipe_through :api
  # end
end
