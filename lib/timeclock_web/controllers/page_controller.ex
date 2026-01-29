defmodule TimeclockWeb.PageController do
  use TimeclockWeb, :controller

  def landing(conn, _params) do
    render(conn, :landing)
  end
end
