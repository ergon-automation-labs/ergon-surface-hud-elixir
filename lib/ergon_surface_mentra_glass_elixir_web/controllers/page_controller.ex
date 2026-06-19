defmodule ErgonSurfaceMentraGlassElixirWeb.PageController do
  use ErgonSurfaceMentraGlassElixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
