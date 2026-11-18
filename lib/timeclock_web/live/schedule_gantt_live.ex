defmodule TimeclockWeb.ScheduleGanttLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "scheduling:schedules")
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "scheduling:shifts")
    end

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
       page_title: "Timeline Gantt Planner",
       schedules: schedules,
       gantt_tasks: build_gantt_tasks(schedules),
       gantt_view_mode: :day,
       user_options: user_options,
       shift_options: shift_options,
       editor_mode: nil,
       selected_schedule: nil,
       form: nil
     )}
  end

  @impl true
  def handle_event("new_schedule", _params, socket) do
    current_user = socket.assigns.current_user

    form =
      Timeclock.Scheduling.Schedule
      |> AshPhoenix.Form.for_create(:create, actor: current_user)
      |> to_form()

    {:noreply, assign(socket, editor_mode: :create, selected_schedule: nil, form: form)}
  end

  @impl true
  def handle_event("select_schedule", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Ash.get(Timeclock.Scheduling.Schedule, id, load: [:user, :shift], actor: current_user) do
      {:ok, schedule} ->
        form =
          schedule
          |> AshPhoenix.Form.for_update(:update, actor: current_user)
          |> to_form()

        {:noreply, assign(socket, editor_mode: :edit, selected_schedule: schedule, form: form)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Schedule not found or access denied.")}
    end
  end

  # Handles GanttEx bar drag/resize events to persist updated start/end timestamps
  @impl true
  def handle_event("gantt_date_change", %{"id" => id, "start" => start_str, "end" => end_str}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, schedule} <- Ash.get(Timeclock.Scheduling.Schedule, id, actor: current_user),
         {:ok, updated} <-
           Ash.update(
             schedule,
             :update,
             %{start_time: start_str, end_time: end_str},
             actor: current_user
           ) do
      broadcast_schedule_change(updated.id)
      schedules = fetch_schedules(current_user)

      {:noreply,
       socket
       |> put_flash(:info, "Shift rescheduled.")
       |> assign(schedules: schedules, gantt_tasks: build_gantt_tasks(schedules))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to reschedule shift.")}
    end
  end

  @impl true
  def handle_event("change_gantt_scale", %{"mode" => mode}, socket) do
    view_mode =
      case mode do
        "day" -> :day
        "week" -> :week
        "month" -> :month
        _ -> :day
      end

    {:noreply, assign(socket, gantt_view_mode: view_mode)}
  end

  @impl true
  def handle_event("close_editor", _params, socket) do
    {:noreply, assign(socket, editor_mode: nil, selected_schedule: nil, form: nil)}
  end

  @impl true
  def handle_event("validate", %{"form" => form_params}, socket) do
    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(form_params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => form_params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: form_params) do
      {:ok, record} ->
        broadcast_schedule_change(record.id)
        schedules = fetch_schedules(current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Roster schedule saved.")
         |> assign(
           schedules: schedules,
           gantt_tasks: build_gantt_tasks(schedules),
           editor_mode: nil,
           selected_schedule: nil,
           form: nil
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("delete_schedule", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, entry} <- Ash.get(Timeclock.Scheduling.Schedule, id, actor: current_user),
         :ok <- Ash.destroy(entry, actor: current_user) do
      broadcast_schedule_change(id)
      schedules = fetch_schedules(current_user)

      {:noreply,
       socket
       |> put_flash(:info, "Schedule entry deleted.")
       |> assign(
         schedules: schedules,
         gantt_tasks: build_gantt_tasks(schedules),
         editor_mode: nil,
         selected_schedule: nil,
         form: nil
       )}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to delete schedule entry.")}
    end
  end

  @impl true
  def handle_info({:schedule_updated, _schedule_id}, socket) do
    schedules = fetch_schedules(socket.assigns.current_user)
    {:noreply, assign(socket, schedules: schedules, gantt_tasks: build_gantt_tasks(schedules))}
  end

  @impl true
  def handle_info({:shift_updated, _shift_id, _name}, socket) do
    shifts = Ash.read!(Timeclock.Scheduling.Shift, actor: socket.assigns.current_user)
    {:noreply, assign(socket, shift_options: Enum.map(shifts, &{&1.name, &1.id}))}
  end

  defp fetch_schedules(current_user) do
    require Ash.Query

    Timeclock.Scheduling.Schedule
    |> Ash.Query.sort(start_time: :asc)
    |> Ash.Query.load([:user, :shift])
    |> Ash.read!(actor: current_user)
  end

  defp build_gantt_tasks(schedules) do
    Enum.map(schedules, fn sched ->
      user_label =
        if sched.user, do: to_string(sched.user.email), else: "Floating Slot"

      shift_label =
        if sched.shift, do: sched.shift.name, else: "Custom Shift"

      %{
        id: sched.id,
        name: "#{user_label} — #{shift_label}",
        start: DateTime.to_iso8601(sched.start_time),
        end: DateTime.to_iso8601(sched.end_time),
        progress: 100
      }
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
          <h1 class="text-2xl font-bold text-gray-900">Timeline Gantt Planner</h1>
          <p class="text-sm text-gray-500">
            Click any shift bar to inspect or drag bars to reschedule roster coverage.
          </p>
        </div>

        <div class="flex items-center gap-3">
          <div class="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-1 text-xs font-semibold">
            <button
              type="button"
              phx-click="change_gantt_scale"
              phx-value-mode="day"
              class={"px-3 py-1 rounded-md transition #{if @gantt_view_mode == :day, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              Day
            </button>
            <button
              type="button"
              phx-click="change_gantt_scale"
              phx-value-mode="week"
              class={"px-3 py-1 rounded-md transition #{if @gantt_view_mode == :week, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              Week
            </button>
            <button
              type="button"
              phx-click="change_gantt_scale"
              phx-value-mode="month"
              class={"px-3 py-1 rounded-md transition #{if @gantt_view_mode == :month, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              Month
            </button>
          </div>

          <button
            :if={manager_or_admin?(@current_user)}
            type="button"
            phx-click="new_schedule"
            class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold px-4 py-2 rounded-lg text-xs transition shadow-sm"
          >
            + Assign Shift
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm overflow-x-auto">
          <div :if={Enum.any?(@gantt_tasks)}>
            <GanttEx.gantt
              id="roster-schedule-gantt"
              tasks={@gantt_tasks}
              view_mode={@gantt_view_mode}
              readonly={!manager_or_admin?(@current_user)}
              on_click="select_schedule"
              on_date_change="gantt_date_change"
            />
          </div>
          <div :if={Enum.empty?(@gantt_tasks)} class="py-16 text-center text-sm text-gray-400">
            No shifts scheduled yet. Click "+ Assign Shift" to create the first roster slot.
          </div>
        </div>

        <div class="lg:col-span-1 bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit space-y-4">
          <div class="flex items-center justify-between border-b pb-2">
            <h2 class="text-lg font-bold text-gray-900">
              {if @editor_mode == :create, do: "Assign New Shift", else: "Workspace Editor"}
            </h2>
            <button
              :if={@editor_mode}
              type="button"
              phx-click="close_editor"
              class="text-xs text-gray-400 hover:text-gray-700"
            >
              Close
            </button>
          </div>

          <div :if={@form} class="space-y-4">
<div :if={@selected_schedule && @selected_schedule.user} class="p-3 bg-slate-50 border rounded-lg text-xs font-semibold">
Employee: {@selected_schedule.user.email}
<.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
<div :if={@editor_mode == :create}>
Employee
<.input
field={@form[:user_id]}
type="select"
options={@user_options}
prompt="Select employee..."
class="w-full text-sm mt-1"
/>
Shift Template
<.input
field={@form[:shift_id]}
type="select"
options={@shift_options}
prompt="Override Shift Type"
class="w-full text-sm mt-1"
/>
Start Time
<.input field={@form[:start_time]} type="datetime-local" class="w-full text-sm mt-1" />
End Time
<.input field={@form[:end_time]} type="datetime-local" class="w-full text-sm mt-1" />
{if @editor_mode == :create, do: "Create Shift", else: "Save Changes"}
<button
:if={@editor_mode == :edit && @selected_schedule}
type="button"
phx-click="delete_schedule"
phx-value-id={@selected_schedule.id}
data-confirm="Delete this shift from the roster?"
class="w-full bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 font-bold py-2 rounded text-sm transition"
>
Delete

</.form>
Select a timeline bar on the Gantt chart or click "+ Assign Shift" to open the editor.




"""
end
end