defmodule TimeclockWeb.ProjectBoardLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "projects:tasks")
    end

    projects = Ash.read!(Timeclock.Projects.Project, actor: current_user)
    tasks = fetch_tasks(current_user)
    assignments = Ash.read!(Timeclock.Projects.Assignment, actor: current_user)

    project_options = Enum.map(projects, &{&1.name, &1.id})

    assignment_options =
      Enum.map(assignments, &{"Assignment: #{String.slice(to_string(&1.id), 0, 8)}", &1.id})

    {:ok,
     assign(socket,
       page_title: "Project Operations & Milestones",
       projects: projects,
       tasks: tasks,
       gantt_tasks: build_gantt_tasks(tasks),
       view_mode: :board,
       gantt_scale: :week,
       project_options: project_options,
       assignment_options: assignment_options,
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
      {:ok, task} ->
        broadcast_task_change(task.id)
        tasks = fetch_tasks(current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Task provisioned.")
         |> assign(
           tasks: tasks,
           gantt_tasks: build_gantt_tasks(tasks),
           form: build_create_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("transition_task", %{"id" => id, "action" => action_name}, socket)
      when action_name in ["start", "complete", "reopen"] do
    current_user = socket.assigns.current_user
    action = String.to_existing_atom(action_name)

    with {:ok, task} <- Ash.get(Timeclock.Projects.Task, id, actor: current_user),
         {:ok, updated} <- Ash.update(task, action, %{}, actor: current_user) do
      broadcast_task_change(updated.id)
      tasks = fetch_tasks(current_user)

      {:noreply,
       socket
       |> put_flash(:info, "Task status updated.")
       |> assign(tasks: tasks, gantt_tasks: build_gantt_tasks(tasks))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to update task state.")}
    end
  end

  @impl true
  def handle_event("switch_view", %{"view" => view}, socket) do
    mode = if view == "gantt", do: :gantt, else: :board
    {:noreply, assign(socket, view_mode: mode)}
  end

  @impl true
  def handle_event("change_gantt_scale", %{"scale" => scale}, socket) do
    gantt_scale =
      case scale do
        "day" -> :day
        "week" -> :week
        "month" -> :month
        _ -> :week
      end

    {:noreply, assign(socket, gantt_scale: gantt_scale)}
  end

  @impl true
  def handle_info({:task_updated, _task_id}, socket) do
    tasks = fetch_tasks(socket.assigns.current_user)
    {:noreply, assign(socket, tasks: tasks, gantt_tasks: build_gantt_tasks(tasks))}
  end

  defp fetch_tasks(current_user) do
    require Ash.Query

    Timeclock.Projects.Task
    |> Ash.Query.sort(due_date: :asc)
    |> Ash.Query.load([:project, :assignment])
    |> Ash.read!(actor: current_user)
  end

  defp build_create_form(current_user) do
    Timeclock.Projects.Task
    |> AshPhoenix.Form.for_create(:create, actor: current_user)
    |> to_form()
  end

  defp build_gantt_tasks(tasks) do
    tasks
    |> Enum.filter(& &1.due_date)
    |> Enum.map(fn t ->
      start_dt = t.created_at || DateTime.add(t.due_date, -1, :day)

      progress =
        case Map.get(t, :state) do
          :completed -> 100
          :in_progress -> 50
          _ -> 10
        end

      project_prefix = if t.project, do: "[#{t.project.name}] ", else: ""

      %{
        id: t.id,
        name: "#{project_prefix}#{t.name}",
        start: DateTime.to_iso8601(start_dt),
        end: DateTime.to_iso8601(t.due_date),
        progress: progress
      }
    end)
  end

  defp broadcast_task_change(task_id) do
    Phoenix.PubSub.broadcast(
      Timeclock.PubSub,
      "projects:tasks",
      {:task_updated, task_id}
    )
  end

  defp manager_or_admin?(%{role: role}) when role in [:admin, :manager], do: true
  defp manager_or_admin?(_), do: false

  defp format_due_date(nil), do: "No deadline"
  defp format_due_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_due_date(%NaiveDateTime{} = ndt), do: Calendar.strftime(ndt, "%Y-%m-%d %H:%M")
  defp format_due_date(other), do: to_string(other)

  defp state_badge(:completed), do: "bg-green-100 text-green-800 border-green-200"
  defp state_badge(:in_progress), do: "bg-blue-100 text-blue-800 border-blue-200"
  defp state_badge(_), do: "bg-amber-100 text-amber-800 border-amber-200"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Project Operations & Milestones</h1>
          <p class="text-sm text-gray-500">
            Allocate project tasks, track milestone deadlines, and monitor active execution states.
          </p>
        </div>

        <div class="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-1 text-xs font-semibold">
          <button
            type="button"
            phx-click="switch_view"
            phx-value-view="board"
            class={"px-3 py-1.5 rounded-md transition #{if @view_mode == :board, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
          >
            Milestone Board
          </button>
          <button
            type="button"
            phx-click="switch_view"
            phx-value-view="gantt"
            class={"px-3 py-1.5 rounded-md transition #{if @view_mode == :gantt, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
          >
            Gantt Timeline
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Manager/Admin Task Provisioning Panel -->
        <div
          :if={manager_or_admin?(@current_user)}
          class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit"
        >
          <h2 class="text-lg font-bold text-gray-900 mb-4">Provision Task</h2>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Task Name
              </label>
              <.input
                field={@form[:name]}
                type="text"
                placeholder="Task Designation Name"
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Project
              </label>
              <.input
                field={@form[:project_id]}
                type="select"
                options={@project_options}
                prompt="Select parent project..."
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Workflow Assignment
              </label>
              <.input
                field={@form[:assignment_id]}
                type="select"
                options={@assignment_options}
                prompt="Select workflow timeline route..."
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Due Date
              </label>
              <.input field={@form[:due_date]} type="datetime-local" class="w-full text-sm" />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Description
              </label>
              <.input
                field={@form[:description]}
                type="textarea"
                placeholder="Detail operational description..."
                rows="3"
                class="w-full text-sm"
              />
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded text-sm transition"
            >
              Launch Task Node
            </button>
          </.form>
        </div>

        <!-- Board or Gantt View Container -->
        <div class={"#{if manager_or_admin?(@current_user), do: "lg:col-span-2", else: "lg:col-span-3"} bg-white p-6 rounded-xl border border-gray-200 shadow-sm"}>
          <div :if={@view_mode == :board}>
            <h2 class="text-lg font-semibold text-gray-800 mb-4">Milestone Operational Board</h2>

            <div :if={Enum.any?(@tasks)} class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div
                :for={t <- @tasks}
                class="p-4 border rounded-xl bg-gray-50/50 flex flex-col justify-between space-y-3"
                id={"task-card-#{t.id}"}
              >
                <div>
                  <div class="flex items-start justify-between gap-2 border-b pb-2">
{t.name}

{if t.project, do: t.project.name, else: "Global"}

<p :if={t.description && t.description != ""} class="text-xs text-gray-600 italic mt-2">
"{t.description}"

Due: {format_due_date(t.due_date)}
<span
:if={Map.get(t, :state)}
class={"px-2 py-0.5 text-[10px] font-mono font-bold uppercase border rounded #{state_badge(Map.get(t, :state))}"}
>
{Map.get(t, :state)}
<button
:if={Map.get(t, :state) in [nil, :todo, :pending]}
type="button"
phx-click="transition_task"
phx-value-id={t.id}
phx-value-action="start"
class="text-[11px] font-semibold text-indigo-600 hover:underline"
>
Start
<button
:if={Map.get(t, :state) == :in_progress}
type="button"
phx-click="transition_task"
phx-value-id={t.id}
phx-value-action="complete"
class="text-[11px] font-semibold text-green-600 hover:underline"
>
Complete




No project tasks provisioned yet.

<div :if={@view_mode == :gantt} class="space-y-4">

Project Milestone Timeline

<button
type="button"
phx-click="change_gantt_scale"
phx-value-scale="day"
class={"px-2.5 py-1 rounded #{if @gantt_scale == :day, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
>
Day

<button
type="button"
phx-click="change_gantt_scale"
phx-value-scale="week"
class={"px-2.5 py-1 rounded #{if @gantt_scale == :week, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
>
Week

<button
type="button"
phx-click="change_gantt_scale"
phx-value-scale="month"
class={"px-2.5 py-1 rounded #{if @gantt_scale == :month, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
>
Month


<GanttEx.gantt
id="project-milestones-gantt"
tasks={@gantt_tasks}
view_mode={@gantt_scale}
readonly={true}
/>
No tasks with due dates available to plot on the Gantt timeline.





"""
end
end