defmodule TimeclockWeb.ScheduleRosterLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "scheduling:schedules")
    end

    today = Date.utc_today()
    schedules = fetch_schedules(current_user)
    shifts = Ash.read!(Timeclock.Scheduling.Shift, actor: current_user)
    users = Ash.read!(Timeclock.Accounts.User, load: [:account], actor: current_user)

    shift_options = Enum.map(shifts, &{&1.name, &1.id})

    user_options =
      Enum.map(users, fn u ->
        label =
          if u.account do
            "#{u.account.first_name} #{u.account.last_name}"
          else
            to_string(u.email)
          end

        {label, u.id}
      end)

    {:ok,
     assign(socket,
       page_title: "Roster Shift Scheduler",
       schedules: schedules,
       shift_options: shift_options,
       user_options: user_options,
       calendar_mode: :week,
       cursor_date: today,
       calendar_days: build_calendar_days(today, :week),
       schedules_by_date: group_schedules_by_date(schedules),
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
      {:ok, record} ->
        broadcast_schedule_change(record.id)
        schedules = fetch_schedules(current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Shift allocation committed.")
         |> assign(
           schedules: schedules,
           schedules_by_date: group_schedules_by_date(schedules),
           form: build_create_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, entry} <- Ash.get(Timeclock.Scheduling.Schedule, id, actor: current_user),
         :ok <- Ash.destroy(entry, actor: current_user) do
      broadcast_schedule_change(id)
      schedules = fetch_schedules(current_user)

      {:noreply,
       socket
       |> put_flash(:info, "Shift allocation revoked.")
       |> assign(
         schedules: schedules,
         schedules_by_date: group_schedules_by_date(schedules)
       )}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Shift not found or access denied.")}
    end
  end

  @impl true
  def handle_event("calendar_nav", %{"dir" => dir}, socket) do
    %{cursor_date: cursor, calendar_mode: mode} = socket.assigns

    new_cursor =
      case {dir, mode} do
        {"today", _} -> Date.utc_today()
        {"prev", :week} -> Date.add(cursor, -7)
        {"next", :week} -> Date.add(cursor, 7)
        {"prev", :month} -> Date.shift(cursor, month: -1)
        {"next", :month} -> Date.shift(cursor, month: 1)
        _ -> cursor
      end

    {:noreply,
     assign(socket,
       cursor_date: new_cursor,
       calendar_days: build_calendar_days(new_cursor, mode)
     )}
  end

  @impl true
  def handle_event("calendar_mode", %{"mode" => mode}, socket) do
    new_mode = if mode == "month", do: :month, else: :week

    {:noreply,
     assign(socket,
       calendar_mode: new_mode,
       calendar_days: build_calendar_days(socket.assigns.cursor_date, new_mode)
     )}
  end

  @impl true
  def handle_info({:schedule_updated, _schedule_id}, socket) do
    schedules = fetch_schedules(socket.assigns.current_user)

    {:noreply,
     assign(socket,
       schedules: schedules,
       schedules_by_date: group_schedules_by_date(schedules)
     )}
  end

  defp fetch_schedules(current_user) do
    require Ash.Query

    Timeclock.Scheduling.Schedule
    |> Ash.Query.sort(start_time: :asc)
    |> Ash.Query.load([:user, :shift])
    |> Ash.read!(actor: current_user)
  end

  defp build_create_form(current_user) do
    Timeclock.Scheduling.Schedule
    |> AshPhoenix.Form.for_create(:create, actor: current_user)
    |> to_form()
  end

  defp build_calendar_days(cursor, :week) do
    week_start = Date.beginning_of_week(cursor, :sunday)
    week_end = Date.end_of_week(cursor, :sunday)
    Date.range(week_start, week_end) |> Enum.to_list()
  end

  defp build_calendar_days(cursor, :month) do
    month_start = Date.beginning_of_month(cursor)
    month_end = Date.end_of_month(cursor)
    grid_start = Date.beginning_of_week(month_start, :sunday)
    grid_end = Date.end_of_week(month_end, :sunday)
    Date.range(grid_start, grid_end) |> Enum.to_list()
  end

  defp group_schedules_by_date(schedules) do
    Enum.group_by(schedules, fn sched ->
      DateTime.to_date(sched.start_time)
    end)
  end

  defp broadcast_schedule_change(schedule_id) do
    Phoenix.PubSub.broadcast(
      Timeclock.PubSub,
      "scheduling:schedules",
      {:schedule_updated, schedule_id}
    )
  end

  defp manager_or_admin?(%{role: role}) when role in [:admin, :manager], do: true
  defp manager_or_admin?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Roster Shift Scheduler</h1>
          <p class="text-sm text-gray-500">
            Allocate shifts, inspect weekly or monthly coverage on the roster calendar, and manage active assignments.
          </p>
        </div>
      </div>

      <!-- Interactive 7-Column Roster Calendar -->
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
            <span class="ml-2 text-sm font-bold text-gray-900">
              {Calendar.strftime(@cursor_date, "%B %Y")}
            </span>
          </div>

          <div class="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-1 text-xs font-semibold">
            <button
              type="button"
              phx-click="calendar_mode"
              phx-value-mode="week"
              class={"px-3 py-1 rounded-md transition #{if @calendar_mode == :week, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              Week
            </button>
            <button
              type="button"
              phx-click="calendar_mode"
              phx-value-mode="month"
              class={"px-3 py-1 rounded-md transition #{if @calendar_mode == :month, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              Month
            </button>
          </div>
        </div>

        <div class="border border-gray-200 rounded-lg overflow-hidden">
          <div class="grid grid-cols-7 bg-gray-50 border-b border-gray-200 text-center text-xs font-bold uppercase tracking-wider text-gray-500">
            <div :for={day_name <- ~w(Sun Mon Tue Wed Thu Fri Sat)} class="py-2 border-r last:border-r-0 border-gray-200">
              {day_name}
            </div>
          </div>

          <div class="grid grid-cols-7 divide-x divide-y divide-gray-200 bg-white">
            <div
              :for={day <- @calendar_days}
              class={"min-h-[110px] p-2 flex flex-col gap-1 #{if day.month != @cursor_date.month && @calendar_mode == :month, do: "bg-gray-50/70 text-gray-400", else: "bg-white"}"}
            >
              <div class="flex items-center justify-between">
                <span class={"text-xs font-mono font-bold #{if day == Date.utc_today(), do: "bg-indigo-600 text-white px-1.5 py-0.5 rounded-full", else: "text-gray-600"}"}>
                  {day.day}
                </span>
              </div>

              <div class="space-y-1 mt-1 overflow-y-auto max-h-24">
                <div
                  :for={s <- Map.get(@schedules_by_date, day, [])}
                  class="px-1.5 py-1 rounded bg-indigo-50 border border-indigo-200 text-[10px] leading-tight text-indigo-900"
                >
                  <div class="font-bold truncate">
                    {if s.user, do: s.user.email, else: "Floating"}
                  </div>
                  <div class="font-mono text-[9px] text-indigo-700 truncate">
                    {if s.shift, do: s.shift.name, else: "Shift"} ({Calendar.strftime(s.start_time, "%H:%M")}-{Calendar.strftime(s.end_time, "%H:%M")})
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

Allocate Shift
<.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
Employee
<.input
field={@form[:user_id]}
type="select"
options={@user_options}
prompt="Select Employee (or leave blank for Floating)"
class="w-full text-sm"
/>
Shift Template
<.input
field={@form[:shift_id]}
type="select"
options={@shift_options}
prompt="Select Shift Rule"
class="w-full text-sm"
/>
Start Time
<.input field={@form[:start_time]} type="datetime-local" class="w-full text-sm" />

End Time
<.input field={@form[:end_time]} type="datetime-local" class="w-full text-sm" />

Commit Shift Allocation

</.form>
<div class={"#{if manager_or_admin?(@current_user), do: "xl:col-span-2", else: "xl:col-span-3"} bg-white p-6 rounded-xl border border-gray-200 shadow-sm"}>
Active Roster Ledger

Employee Context	Shift Parameter Map	Timeframe Bounds	Actions
{if s.user, do: s.user.email, else: "Floating"}
		{Calendar.strftime(s.start_time, "%Y-%m-%d %H:%M")} → {Calendar.strftime(s.end_time, "%Y-%m-%d %H:%M")}	
No active shift allocations scheduled yet.

"""
end
end