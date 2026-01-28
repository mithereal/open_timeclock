defmodule TimeclockWeb.ScheduleGanttComponent do
  use Phoenix.LiveComponent
  use Gettext, backend: TimeclockWeb.Gettext
  # users: [%{id: "xxxx-xxxx-xxxx-xxxx"}, _]
  # schedules: [{"xxxx-xxxx-xxxx-xxxx",[start_datetime: datetime,  end_datetime: datetime]}, _list, _list]
  attr :dates, :list, required: true
  attr :users, :list, required: true
  attr :schedules, :list, required: true
  attr :today, :string, required: true
  attr :modal_open, :boolean, default: false
  attr :modal_schedule, :map, default: %{}

  def gantt_chart(assigns) do
    ~H"""
    <div class="overflow-auto border rounded shadow">
      <!-- Header -->
      <div class="grid grid-cols-[200px_repeat(var(--days),1fr)] bg-gray-100 border-b">
        <div class="p-2 font-bold">Users</div>
        <div :for={date <- @dates} class="p-2 font-bold text-center border-l">
          <%= if date == @today do %>
            "<div class="mx-auto mb-1 px-2 py-0.5 bg-green-500 text-white text-xs rounded-full w-fit"></div>"
          <% end %>

          <.gantt_date_component date={date} />
        </div>
      </div>
      
    <!-- Rows for each user -->
      <div :for={user <- @users} class="grid grid-cols-[200px_repeat(var(--days),1fr)] border-b">
        <div class="p-2 font-medium bg-gray-50 flex items-center gap-2">
          <%= if Map.has_key?(user, :avatar_url) do %>
            "<img src={user.avatar_url} alt={user.name} class="w-6 h-6 rounded-full object-cover" />"
          <% end %>

          <span>{user.name}</span>
        </div>
        
    <!-- Day columns -->
        {user_schedules = find_schedules_for_user(@schedules, user.id, @dates)}
        <div
          :for={date <- @dates}
          class="relative border-l p-1 min-h-[3rem]"
          id={"#{user.name}-#{date}"}
          phx-hook=".schedule_drag"
          data-user_id={user.id}
        >
          {schedules_for_date = find_schedules_by_date(user_schedules, date)}
          <.gantt_schedule
            :for={s <- @schedules_for_date}
            item={s.item}
            left={s.left}
            width={s.width}
            user_id={s.user_id}
          />
        </div>
      </div>
    </div>

    <.live_component
      module={__MODULE__}
      id="schedule_modal"
      schedule={@modal_schedule}
      show={@modal_open}
    />

    <!-- Drag & drop hook -->
    <script :type={Phoenix.LiveView.ColocatedHook} name=".schedule_drag">
      export default {
        mounted() {
          this.el.addEventListener('dragstart', (e) => {
            e.dataTransfer.effectAllowed = "move"
            e.dataTransfer.setData('text/plain', JSON.stringify({
              user_id: this.el.dataset.user_id,
              label: this.el.dataset.label,
              start_datetime: this.el.dataset.start_datetime,
              end_datetime: this.el.dataset.end_datetime
            }))
            this.el.classList.add("opacity-50", "scale-105")
          })
          this.el.addEventListener('dragend', (e) => {
            this.el.classList.remove("opacity-50", "scale-105")
          })
      this.el.addEventListener('dragover', (e) => e.preventDefault())
        this.el.addEventListener('drop', (e) => {
          e.preventDefault()
          const data = JSON.parse(e.dataTransfer.getData('text/plain'))
          if (data.user_id !== this.el.dataset.user_id || data.user_id !== this.el.dataset.user_id) return
          this.pushEvent("multi_day_shift_dropped", {
            user_id: data.user.id,
            label: data.label,
            start_datetime: data.start_datetime,
            end_datetime: data.end_datetime,
            to_index: Array.from(this.el.parentElement.children).indexOf(this.el)
          })
        })
              }
            }
    </script>
    """
  end

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end

  # Schedule Item rendering
  attr :user_id, :string, required: true
  attr :left, :string, required: true
  attr :width, :string, required: true
  attr :item, :map, required: true

  def gantt_schedule(assigns) do
    ~H"""
    <div
      class={"absolute top-0 p-1 text-xs rounded cursor-pointer flex items-center justify-center #{@item.color} hover:scale-105 transform transition duration-200"}
      style={"left: #{@left}%; width: #{@width}%; transition-all duration-300;"}
      draggable={@user_id == @item.user_id}
      phx-click="edit_schedule"
      phx-value-user_id={@user_id}
      phx-value-label={@item.label}
      phx-value-start_datetime={@item.start_datetime}
      phx-value-end_datetime={@item.end_datetime}
      phx-value-color={@item.color}
    >
      <span>{@item.icon}</span> {@item.label}
    </div>
    """
  end

  attr :schedule, :map, required: true
  attr :show, :boolean, required: true
  attr :user_id, :string, required: true

  def gantt_modal_component(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
    >
      <div class="bg-white rounded-lg p-6 w-96 shadow-lg">
        <h2 class="text-lg font-bold mb-4">Edit Schedule</h2>
        <form phx-submit="save_schedule" phx-target={@myself}>
          <input
            type="hidden"
            name="user_id"
            value={@user_id}
          />

          <div class="mb-3">
            <label class="block text-sm font-medium">Start Day</label>
            <input
              type="text"
              name="start_day"
              value={@schedule.start_datetime}
              class="border p-2 w-full rounded"
            />
          </div>
          <div class="mb-3">
            <label class="block text-sm font-medium">End Day</label>
            <input
              type="text"
              name="end_day"
              value={@schedule.end_datetime}
              class="border p-2 w-full rounded"
            />
          </div>
          <div class="mb-3">
            <label class="block text-sm font-medium">Label</label>
            <input type="text" name="label" value={@schedule.label} class="border p-2 w-full rounded" />
          </div>
          <div class="mb-3">
            <label class="block text-sm font-medium">Color</label>
            <input type="color" name="color" value={@schedule.color} class="w-full h-10 rounded" />
          </div>
          <div class="flex justify-end gap-2 mt-4">
            <button
              type="button"
              phx-click="close_modal"
              phx-target={@myself}
              class="px-4 py-2 bg-gray-300 rounded"
            >
              Cancel
            </button>
            <button type="submit" class="px-4 py-2 bg-blue-500 text-white rounded">Save</button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :date, :string, required: true

  def gantt_date_component(assigns) do
    {day_num, day_string} = format_date(assigns["date"])

    assign_new(assigns, :day_num, fn -> day_num end)
    |> assign_new(:day_string, fn -> day_string end)

    ~H"""
    <div class="p-2 font-bold text-center border-l">
      <div>{@day_num}</div>
      <div>{@day_string}</div>
    </div>
    """
  end

  def handle_event("close_modal", _params, socket), do: {:noreply, assign(socket, show: false)}

  def handle_event(
        "save_schedule",
        %{
          "user_id" => user_id,
          "start_datetime" => start_datetime,
          "end_datetime" => end_datetime,
          "label" => label,
          "color" => color
        },
        socket
      ) do
    data = %{
      user_id: user_id,
      start_datetime: start_datetime,
      end_datetime: end_datetime,
      label: label,
      color: color
    }

    send(
      self(),
      {:save_schedule, data}
    )

    {:noreply, assign(socket, show: false)}
  end

  defp find_schedules_for_user(schedules, user_id, dates) when is_list(dates) do
    case Enum.find(schedules, fn {u, _} -> u == user_id end) do
      nil ->
        []

      {_, schedules} ->
        for item <- schedules do
          start_index = Enum.find_index(dates, &(&1 == item.start_datetime)) || 0
          end_index = Enum.find_index(dates, &(&1 == item.end_datetime)) || start_index
          span = end_index - start_index + 1
          width = span / length(dates) * 100
          left = start_index / length(dates) * 100
          %{item: item, left: left, width: width, user_id: user_id}
        end
    end
  end

  defp find_schedules_by_date(schedules, date) do
    Enum.find(schedules, fn {_u, s} ->
      Timex.diff(s.start_date, date, :day) == 0 || Timex.diff(s.end_date, date, :day) == 0
    end)
  end

  defp format_date(datetime) do
    day_name =
      datetime
      |> Timex.weekday()
      |> Timex.day_shortname()

    {datetime.day, day_name}
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(TimeclockWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(TimeclockWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
