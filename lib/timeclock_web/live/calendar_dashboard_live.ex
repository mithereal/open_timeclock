defmodule TimeclockWeb.CalendarDashboardLive do
  use TimeclockWeb, :live_view

  @recurring_options [
    {"None (Single Occurrence)", "none"},
    {"Weekly", "weekly"},
    {"Monthly", "monthly"},
    {"Yearly (Auto-Rollover)", "yearly"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    groups = Ash.read!(Timeclock.Calendar.Group, actor: current_user)
    events = fetch_events(current_user)

    if connected?(socket) do
      Enum.each(groups, fn group ->
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "calendar_events:#{group.id}")
      end)
    end

    today = Date.utc_today()

    {:ok,
     assign(socket,
       page_title: "Institutional Event Matrix",
       events: events,
       groups: groups,
       group_options: Enum.map(groups, &{&1.name, &1.id}),
       recurring_options: @recurring_options,
       cursor_date: today,
       calendar_days: build_month_days(today),
       events_by_date: group_events_by_date(events),
       form: build_create_form(current_user)
     )}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _event} ->
        events = fetch_events(current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Calendar event published.")
         |> assign(
           events: events,
           events_by_date: group_events_by_date(events),
           form: build_create_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, item} <- Ash.get(Timeclock.Calendar.Event, id, actor: current_user),
         :ok <- Ash.destroy(item, actor: current_user) do
      events = fetch_events(current_user)

      {:noreply,
       socket
       |> put_flash(:info, "Calendar event purged.")
       |> assign(events: events, events_by_date: group_events_by_date(events))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Event not found or access denied.")}
    end
  end

  @impl true
  def handle_event("calendar_nav", %{"dir" => dir}, socket) do
    cursor = socket.assigns.cursor_date

    new_cursor =
      case dir do
        "today" -> Date.utc_today()
        "prev" -> Date.shift(cursor, month: -1)
        "next" -> Date.shift(cursor, month: 1)
        _ -> cursor
      end

    {:noreply,
     assign(socket,
       cursor_date: new_cursor,
       calendar_days: build_month_days(new_cursor)
     )}
  end

  @impl true
  def handle_info({:calendar_event_updated, _event_id, _date}, socket) do
    events = fetch_events(socket.assigns.current_user)
    {:noreply, assign(socket, events: events, events_by_date: group_events_by_date(events))}
  end

  defp fetch_events(current_user) do
    require Ash.Query

    Timeclock.Calendar.Event
    |> Ash.Query.sort(date: :asc)
    |> Ash.Query.load([:group])
    |> Ash.read!(actor: current_user)
  end

  defp build_create_form(current_user) do
    Timeclock.Calendar.Event
    |> AshPhoenix.Form.for_create(:create,
      params: %{"recurring_mode" => "none", "type" => %{}},
      actor: current_user
    )
    |> to_form()
  end

  defp build_month_days(cursor) do
    month_start = Date.beginning_of_month(cursor)
    month_end = Date.end_of_month(cursor)
    grid_start = Date.beginning_of_week(month_start, :sunday)
    grid_end = Date.end_of_week(month_end, :sunday)
    Date.range(grid_start, grid_end) |> Enum.to_list()
  end

  defp group_events_by_date(events) do
    Enum.reduce(events, %{}, fn evt, acc ->
      end_date = evt.valid_to || evt.date
      span_end = if Date.compare(end_date, evt.date) == :lt, do: evt.date, else: end_date

      # Cap multi-day expansion to 60 days per event in memory for safety
      capped_end =
        if Date.diff(span_end, evt.date) > 60 do
          Date.add(evt.date, 60)
        else
          span_end
        end

      Date.range(evt.date, capped_end)
      |> Enum.reduce(acc, fn day, day_acc ->
        Map.update(day_acc, day, [evt], &[evt | &1])
      end)
    end)
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Institutional Event Matrix</h1>
        <p class="text-sm text-gray-500 mt-1">
          Manage company holidays, recurring schedule events, and group-scoped calendar exceptions.
        </p>
      </div>

      <!-- Interactive 7-Column Monthly Calendar -->
      <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div class="flex items-center gap-2">
            <button
              type="button"
              phx-click="calendar_nav"
              phx-value-dir="prev"
              class="px-2.5 py-1.5 rounded-lg border border-gray-200 text-xs font-semibold text-gray-700 hover:bg-gray-50"
            >
              ← Prev
            </button>
            <button
              type="button"
              phx-click="calendar_nav"
              phx-value-dir="today"
              class="px-3 py-1.5 rounded-lg border border-gray-200 text-xs font-semibold text-gray-700 hover:bg-gray-50"
            >
              Today
            </button>
            <button
              type="button"
              phx-click="calendar_nav"
              phx-value-dir="next"
              class="px-2.5 py-1.5 rounded-lg border border-gray-200 text-xs font-semibold text-gray-700 hover:bg-gray-50"
            >
              Next →
            </button>
            <span class="ml-2 text-base font-bold text-gray-900">
              {Calendar.strftime(@cursor_date, "%B %Y")}
            </span>
          </div>
        </div>

        <div class="border border-gray-200 rounded-lg overflow-hidden">
          <div class="grid grid-cols-7 bg-gray-50 border-b border-gray-200 text-center text-xs font-bold uppercase tracking-wider text-gray-500">
            <div
              :for={day_name <- ~w(Sun Mon Tue Wed Thu Fri Sat)}
              class="py-2 border-r last:border-r-0 border-gray-200"
            >
              {day_name}
            </div>
          </div>

          <div class="grid grid-cols-7 divide-x divide-y divide-gray-200 bg-white">
            <div
              :for={day <- @calendar_days}
              class={"min-h-[105px] p-2 flex flex-col gap-1 #{if day.month != @cursor_date.month, do: "bg-gray-50/70 text-gray-400", else: "bg-white"}"}
            >
              <div class="flex items-center justify-between">
                <span class={"text-xs font-mono font-bold #{if day == Date.utc_today(), do: "bg-indigo-600 text-white px-1.5 py-0.5 rounded-full", else: "text-gray-600"}"}>
                  {day.day}
                </span>
              </div>

              <div class="space-y-1 mt-1 overflow-y-auto max-h-20">
                <div
                  :for={evt <- Enum.reverse(Map.get(@events_by_date, day, []))}
                  class="px-1.5 py-0.5 rounded bg-indigo-50 border border-indigo-200 text-[10px] font-semibold text-indigo-900 truncate"
                  title={evt.name}
                >
                  {evt.name}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div
          :if={admin?(@current_user)}
          class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit"
        >
          <h2 class="text-lg font-bold text-gray-900 mb-4">Publish Event</h2>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Event Name
              </label>
              <.input
                field={@form[:name]}
                type="text"
                placeholder="Annual Company Holiday"
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Calendar Group
              </label>
              <.input
                field={@form[:group_id]}
                type="select"
                options={@group_options}
                prompt="Select Target Calendar Group..."
                class="w-full text-sm"
              />
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  Start Date
                </label>
                <.input field={@form[:date]} type="date" class="w-full text-sm" />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  Valid To (Optional)
                </label>
                <.input field={@form[:valid_to]} type="date" class="w-full text-sm" />
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Recurrence Mode
              </label>
<.input
field={@form[:recurring_mode]}
type="select"
options={@recurring_options}
class="w-full text-sm"
/>
Classification Embed

<.inputs_for :let={sub} field={@form[:type]}>

<.input
field={sub[:name]}
type="text"
placeholder="Holiday Code Name"
class="w-full text-xs bg-white"
/>


<.input
field={sub[:value]}
type="number"
placeholder="Weight Factor ID"
class="w-full text-xs bg-white"
/>

</.inputs_for>
Deploy Event

</.form>
<div class={"#{if admin?(@current_user), do: "lg:col-span-2", else: "lg:col-span-3"} bg-white p-6 rounded-xl border border-gray-200 shadow-sm"}>
Calendar Event Logging Board

Event Frame	Group Target	Recurrence	Duration Bounds	Actions
		{e.recurring_mode}	{e.date} → {e.valid_to || "Single Day"}	
No calendar events published yet.

"""
end
end