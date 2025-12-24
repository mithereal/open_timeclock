defmodule TimeclockWeb.PageController do
  use TimeclockWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
