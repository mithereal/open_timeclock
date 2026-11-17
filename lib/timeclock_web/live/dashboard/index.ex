defmodule TimeclockWeb.Dashboard.IndexLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "clockings:live")
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "scheduling:schedules")

      if manager_or_admin?(current_user) do
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "approvals:queue")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "absences:queue")
      end
    end

    {:ok,
     socket
     |> assign(page_title: "Dashboard Gateway")
     |> load_metrics(current_user)}
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, load_metrics(socket, socket.assigns.current_user)}
  end

  defp load_metrics(socket, current_user) do
    user_count = safe_count(Timeclock.Accounts.User, current_user)
    project_count = safe_count(Timeclock.Projects.Project, current_user)
    active_shifts = safe_count(Timeclock.Scheduling.Shift, current_user)

    pending_reviews =
      if manager_or_admin?(current_user) do
        pending_absences =
          Timeclock.Absences.Absence
          |> Ash.Query.filter(state in [:pending, :escalated])
          |> safe_count(current_user)

        pending_approvals =
          Timeclock.Approvals.Approval
          |> Ash.Query.filter(state in [:pending, :escalated])
          |> safe_count(current_user)

        pending_absences + pending_approvals
      else
        0
      end

    assign(socket,
      user_count: user_count,
      project_count: project_count,
      active_shifts: active_shifts,
      pending_reviews: pending_reviews
    )
  end

  defp safe_count(query_or_resource, actor) do
    case Ash.count(query_or_resource, actor: actor) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  defp manager_or_admin?(%{role: role}) when role in [:admin, :manager], do: true
  defp manager_or_admin?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-8">
      <div>
        <h1 class="text-3xl font-extrabold tracking-tight text-gray-900">Workforce Dashboard Gateway</h1>
        <p class="text-sm text-gray-500 mt-1">
          Welcome back. Monitor live workspace metrics and jump directly to your authorized modules.
        </p>
      </div>

      <!-- Overview Metric Cards -->
      <div class={"grid grid-cols-1 #{if manager_or_admin?(@current_user), do: "sm:grid-cols-4", else: "sm:grid-cols-3"} gap-6"}>
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm transition hover:shadow-md">
          <span class="block text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Identities Visible
          </span>
          <span class="block text-3xl font-black text-indigo-600 mt-2">{@user_count} Users</span>
        </div>

        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm transition hover:shadow-md">
          <span class="block text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Operational Trackers
          </span>
          <span class="block text-3xl font-black text-blue-600 mt-2">{@project_count} Projects</span>
        </div>

        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm transition hover:shadow-md">
          <span class="block text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Configured Rotations
          </span>
          <span class="block text-3xl font-black text-purple-600 mt-2">{@active_shifts} Shifts</span>
        </div>

        <div
          :if={manager_or_admin?(@current_user)}
          class="bg-white p-6 rounded-xl border border-amber-200 shadow-sm transition hover:shadow-md"
        >
          <span class="block text-xs font-semibold text-amber-700 uppercase tracking-wider">
            Awaiting Sign-Off
          </span>
          <span class="block text-3xl font-black text-amber-600 mt-2">{@pending_reviews} Pending</span>
        </div>
      </div>

      <!-- Role-Filtered Navigation Shortcuts -->
      <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
        <h2 class="text-lg font-bold text-gray-900">Operational Quick Access Shortcuts</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <.link
            navigate={~p"/home/terminal"}
            class="p-4 border border-gray-200 rounded-xl hover:bg-slate-50 transition block group shadow-2xs"
          >
            <span class="block font-bold text-gray-900 group-hover:text-indigo-600 transition-colors">
              Clocking Terminal
            </span>
            <span class="block text-xs text-gray-500 mt-1">
              Open employee punch-clock terminal and live punch stream.
            </span>
          </.link>

          <.link
            navigate={~p"/home/time-off"}
            class="p-4 border border-gray-200 rounded-xl hover:bg-slate-50 transition block group shadow-2xs"
          >
            <span class="block font-bold text-gray-900 group-hover:text-indigo-600 transition-colors">
              Time-Off Requests
            </span>
            <span class="block text-xs text-gray-500 mt-1">
              Submit leave requests and track workflow approval states.
            </span>
          </.link>

          <.link
            :if={manager_or_admin?(@current_user)}
            navigate={~p"/admin/approvals"}
            class="p-4 border border-gray-200 rounded-xl hover:bg-slate-50 transition block group shadow-2xs"
          >
            <span class="block font-bold text-gray-900 group-hover:text-indigo-600 transition-colors">
              Workflow Approvals
            </span>
            <span class="block text-xs text-gray-500 mt-1">
              Review pending and escalated absences and schedule overrides.
            </span>
          </.link>

          <.link
            :if={manager_or_admin?(@current_user)}
            navigate={~p"/admin/roster-planner"}
            class="p-4 border border-gray-200 rounded-xl hover:bg-slate-50 transition block group shadow-2xs"
          >
            <span class="block font-bold text-gray-900 group-hover:text-indigo-600 transition-colors">
              Shift Scheduler
            </span>
            <span class="block text-xs text-gray-500 mt-1">
              Assign workforce timelines and manage roster coverage.
            </span>
          </.link>

          <.link
            :if={admin?(@current_user)}
            navigate={~p"/admin/infrastructure"}
            class="p-4 border border-gray-200 rounded-xl hover:bg-slate-50 transition block group shadow-2xs"
          >
            <span class="block font-bold text-gray-900 group-hover:text-indigo-600 transition-colors">
              Infrastructure Units
            </span>
            <span class="block text-xs text-gray-500 mt-1">
              Configure company entities, branches, and departments.
            </span>
          </.link>

          <.link
            :if={admin?(@current_user)}
            navigate={~p"/admin/system-settings"}
            class="p-4 border border-gray-200 rounded-xl hover:bg-slate-50 transition block group shadow-2xs"
          >
            <span class="block font-bold text-gray-900 group-hover:text-indigo-600 transition-colors">
              System Settings
            </span>
            <span class="block text-xs text-gray-500 mt-1">
              Update encrypted outbound email and provider credentials.
            </span>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
