defmodule TimeclockWeb.Dashboard.IndexLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:presence_status, [])
      |> assign(:category, "dashboard")
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
    >
      <div class="dark:bg-black">
        <div class="flex mx-auto gap-4 px-4">
          <div class="flex-col w-1/2 mt-4">
            <.web_clock current_user={@current_user} />
            <.user_day current_user={@current_user} />
            <.user_absence_requests current_user={@current_user} />
          </div>

          <div class="flex-col w-1/2 mt-4">
            <.presence presence_status={@presence_status} current_user={@current_user} />
          </div>
        </div>
      </div>
    </Layouts.user_app>
    """
  end

  @impl true
  def handle_info({:chart_datapoint, {x, y}}, socket) do
    %{chart: chart, chart_data: data} = socket.assigns

    data = [%{x: x, y: y} | data]
    series = [%{data: Enum.reverse(data)}]

    socket =
      socket
      |> assign(:chart_data, data)
      |> LiveCharts.push_update(chart, series)

    {:noreply, socket}
  end
end
