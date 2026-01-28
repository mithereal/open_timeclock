defmodule TimeclockWeb.Dashboard.Index do
  use TimeclockWeb, :live_view

  alias Framework.Accounts
  alias Framework.Accounts.Account

  alias TimeclockWeb.Presence
  alias Framework.Presence, as: Server

  @presence "admin:presence"

  alias Framework.Menu

  @impl true
  def mount(_params, _session, socket) do
    {:ok, dashboard} = Menu.dashboard()

    socket =
      socket
      |> assign(:category, :dashboard)
      |> assign(:dashboard, dashboard)
      |> assign(:menu, [])
      |> assign(:page_title, "Home")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.user_app
      flash={@flash}
      page_title={@page_title}
      menu={@menu}
      current_scope={@current_scope}
    >
      <div class="mx-4 dark:bg-black"></div>
    </Layouts.user_app>
    """
  end

  def handle_info(
        {_requesting_module, [:data, :updated], :refresh_users} =
          data,
        socket
      ) do
    socket =
      assign(socket, :active_users, Framework.Accounts.list_users())
      |> assign(:total_users, Framework.Accounts.count_users())

    {:noreply, socket}
  end
end
