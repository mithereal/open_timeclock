defmodule TimeclockWeb.Components.Timeline do
  use Phoenix.Component

  @hours Enum.to_list(0..12)

  attr :points, :list, default: []

  def timeline(assigns) do
    ~H"""
    <div class="w-full p-6">
      <!-- Timeline Track -->
      <div class="relative w-full h-16">
        
    <!-- Horizontal Line -->
        <div class="absolute top-8 left-0 right-0 h-1 bg-gray-300 rounded"></div>
        
    <!-- Hour Ticks -->
        <%= for hour <- @hours do %>
          <div
            class="absolute top-6 -translate-x-1/2 text-xs text-gray-600"
            style={"left: #{hour_percent(hour)}%;"}
          >
            <div class="w-0.5 h-4 bg-gray-400 mx-auto"></div>
            <div class="mt-1">
              {format_hour(hour)}
            </div>
          </div>
        <% end %>
        
    <!-- Time Points -->
        <%= for point <- @points do %>
          <div
            class={"absolute top-8 -translate-x-1/2 -translate-y-1/2
                    w-4 h-4 rounded-full border-2 border-white shadow
                    #{point.color}"}
            style={"left: #{time_percent(point.time)}%;"}
          >
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  ## Position Helpers

  # Convert hour to %
  defp hour_percent(hour) do
    hour / 12 * 100
  end

  # Convert time to %
  defp time_percent(time) do
    {hour, minute} = parse_time(time)
    total_minutes = hour * 60 + minute
    percent = total_minutes / (12 * 60) * 100
    percent
  end

  ## Formatting

  defp format_hour(0), do: "12a"
  defp format_hour(12), do: "12p"
  defp format_hour(h), do: "#{h}a"

  ## Parsing

  defp parse_time(%NaiveDateTime{hour: h, minute: m}), do: {h, m}
  defp parse_time(%DateTime{hour: h, minute: m}), do: {h, m}

  defp parse_time(time) when is_binary(time) do
    [h, m] = String.split(time, ":")
    {String.to_integer(h), String.to_integer(m)}
  end
end
