defmodule TimeclockWeb.AshScope do
  @moduledoc """
  Helper for passing scope to LiveViews.
  """

  import Phoenix.Component
  use TimeclockWeb, :verified_routes

  def on_mount(:current_scope, _params, session, socket) do
    if socket.assigns[:current_user] do
      current_scope = %Timeclock.Scope{current_user: socket.assigns[:current_user].email}
      {:cont, assign(socket, :current_scope, current_scope)}
    else
      {:cont, socket}
    end
  end
end
