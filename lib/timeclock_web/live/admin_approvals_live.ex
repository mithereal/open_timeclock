defmodule TimeclockWeb.AdminApprovalsLive do
  use TimeclockWeb, :live_view
  import AshPhoenix.Form

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :ok

    absences = fetch_pending_absences()
    approvals = fetch_pending_approvals()

    comment_form =
      Timeclock.Approvals.Approval
      |> AshPhoenix.Form.for_create(:create, params: %{"additional_data" => %{}})
      |> to_form()

    {:ok,
     assign(socket,
       absences: absences,
       approvals: approvals,
       comment_form: comment_form,
       page_title: "Workflow Approvals Matrix"
     )}
  end

  @impl true
  def handle_event("approve_absence", %{"id" => id}, socket) do
    case Ash.get(Timeclock.Absences.Absence, id) do
      {:ok, absence} ->
        updated_absence =
          absence
          |> Ash.Changeset.for_update(:update, %{status: "approved"})
          |> Ash.update!()

        if updated_absence.user_id do
          # Build parameters and insert a background job into Oban's transactional outbox
          %{
            "user_id" => updated_absence.user_id,
            "url" => url(socket, ~p"/home/time-off"),
            "subject" => "Time-off Request Approved!"
          }

          | |> Timeclock.Workers.EmailDeliveryWorker.new()
          |> Oban.insert!()
        end

        {:noreply, socket |> put_flash(:info, "Absence request approved. Background worker spawned.") |> assign(absences: fetch_pending_absences())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Target entry could not be verified.")}
    end
  end

  @impl true
  def handle_event("reject_absence", %{"id" => id}, socket) do
    case Ash.get(Timeclock.Absences.Absence, id) do
      {:ok, absence} ->
        updated_absence =
          absence
          |> Ash.Changeset.for_update(:update, %{status: "rejected"})
          |> Ash.update!()

        if updated_absence.user_id do
          %{
            "user_id" => updated_absence.user_id,
            "url" => url(socket, ~p"/home/time-off"),
            "subject" => "Time-off Request Denied"
          }

          | |> Timeclock.Workers.EmailDeliveryWorker.new()
          |> Oban.insert!()
        end

        {:noreply, socket |> put_flash(:info, "Absence request rejected. Background worker spawned.") |> assign(absences: fetch_pending_absences())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Target entry could not be verified.")}
    end
  end

  @impl true
  def handle_event("approve_workflow", %{"id" => id}, socket) do
    case Ash.get(Timeclock.Approvals.Approval, id) do
      {:ok, approval} ->
        updated_approval =
          approval
          |> Ash.Changeset.for_update(:update, %{
            status: "approved", 
            status_set_by_user_id: socket.assigns.current_user.id
          })
          |> Ash.update!()

        if updated_approval.user_id do
          %{
            "user_id" => updated_approval.user_id,
            "url" => url(socket, ~p"/home"),
            "subject" => "Schedule Override Approved!"
          }

          | |> Timeclock.Workers.EmailDeliveryWorker.new()
          |> Oban.insert!()
        end

        {:noreply, socket |> put_flash(:info, "Workflow signed off. Background worker spawned.") |> assign(approvals: fetch_pending_approvals())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Workflow entry verification failure.")}
    end
  end

  @impl true
  def handle_event("reject_workflow", %{"id" => id}, socket) do
    case Ash.get(Timeclock.Approvals.Approval, id) do
      {:ok, approval} ->
        updated_approval =
          approval
          |> Ash.Changeset.for_update(:update, %{
            status: "rejected", 
            status_set_by_user_id: socket.assigns.current_user.id
          })
          |> Ash.update!()

        if updated_approval.user_id do
          %{
            "user_id" => updated_approval.user_id,
            "url" => url(socket, ~p"/home"),
            "subject" => "Schedule Override Rejected"
          }

          | |> Timeclock.Workers.EmailDeliveryWorker.new()
          |> Oban.insert!()
        end

        {:noreply, socket |> put_flash(:info, "Workflow rejected. Background worker spawned.") |> assign(approvals: fetch_pending_approvals())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Workflow entry verification failure.")}
    end
  end

  defp fetch_pending_absences do
    Timeclock.Absences.Absence
    |> Ash.Query.filter(status == "pending")
    |> Ash.Query.load([:user, :definition])
    |> Ash.read!()
  end

  defp fetch_pending_approvals do
    Timeclock.Approvals.Approval
    |> Ash.Query.filter(status == "pending")
    |> Ash.Query.load([:user, :request_definition, :additional_data])
    |> Ash.read!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-8">
      <div>
        <h1 class="text-3xl font-extrabold tracking-tight text-gray-900">Administrative Operations Matrix</h1>
        <p class="text-sm text-gray-500 mt-1">Review active workforce queue nodes, approve sub-day entries, and clear system allocation flags with automated, queue-backed notifier hooks.</p>
      </div>

      <div class="grid grid-cols-1 gap-8">
        
        <!-- SECTION 1: Time-Off Absence Requests Roster Grid -->
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
          <div class="flex items-center justify-between border-b pb-2">
            <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2">🌴 Pending Absence Verification Queue</h2>
            <span class="badge badge-neutral font-mono">{Enum.count(@absences)} entries</span>
          </div>

          <div class="overflow-x-auto">
            <table class="table w-full text-sm text-left">
              <thead>
                <tr class="bg-gray-50 text-gray-500 font-semibold">
                  <th class="p-3">Applicant Profile</th>
                  <th class="p-3">Leave Type</th>
                  <th class="p-3">Proposed Horizon Boundaries</th>
                  <th class="p-3 text-right">Commit Action Matrix</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={abs <- @absences} id={"abs-verify-#{abs.id}"}>
                  <td class="p-3 font-medium text-gray-900">
                    {if abs.user, do: abs.user.email, default: "Profile Ref Lost"}
                  </td>
                  <td class="p-3">
                    <span class="px-2 py-0.5 rounded text-xs bg-amber-50 text-amber-800 border border-amber-200 font-semibold">
                      {if abs.definition, do: abs.definition.name, default: "Standard Request"}
                    </span>
                    <p :if={Map.has_key?(abs, :comment) && abs.comment} class="text-[11px] text-gray-400 italic mt-1">
                      "{abs.comment}"
                    </p>
                  </td>
                  <td class="p-3 font-mono text-xs text-gray-500">
                    {abs.start_date} ➔ {abs.end_date}
                  </td>
                  <td class="p-3 text-right space-x-2">
                    <button type="button" phx-click="approve_absence" phx-value-id={abs.id} class="px-3 py-1 rounded bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-xxs transition">
                      Approve
                    </button>
                    <button type="button" phx-click="reject_absence" phx-value-id={abs.id} class="px-3 py-1 rounded bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 text-xs font-bold transition">
                      Reject
                    </button>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@absences)}>
                  <td colspan="4" class="p-8 text-center text-gray-400 italic">No time-off requests pending clearance signature blocks.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- SECTION 2: General Allocation & Adjustments Approvals Queue -->
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
          <div class="flex items-center justify-between border-b pb-2">
            <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2">⚙️ Cross-Department Workflows Ledger</h2>
            <span class="badge badge-neutral font-mono">{Enum.count(@approvals)} entries</span>
          </div>

          <div class="overflow-x-auto">
            <table class="table w-full text-sm text-left">
              <thead>
                <tr class="bg-gray-50 text-gray-500 font-semibold">
                  <th class="p-3">Context Target</th>
                  <th class="p-3">Definition Route</th>
                  <th class="p-3">Allocation Window Bounds</th>
                  <th class="p-3 text-right">Commit Action Matrix</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={app <- @approvals} id={"app-verify-#{app.id}"} class={if app.is_dirty, do: "bg-rose-50/30", default: ""}>
                  <td class="p-3 font-medium text-gray-900">
                    {if app.user, do: app.user.email, default: "Identity Context"}
                    <span :if={app.is_dirty} class="block text-[9px] font-black text-rose-700 uppercase tracking-tight mt-0.5 animate-pulse">
                      ⚠️ Data Field Flags Flagged Dirty
                    </span>
                  </td>
                  <td class="p-3">
                    <span class="font-bold text-gray-800 block text-xs">
                      {if app.request_definition, do: app.request_definition.name, default: "Standard Adjust Envelope"}
                    </span>
                    <div :if={app.additional_data} class="text-[10px] text-gray-400 italic mt-0.5 space-y-0.5">
                      <p :if={app.additional_data.appliers_comment}>💬 Applier: "{app.additional_data.appliers_comment}"</p>
                    </div>
                  </td>
                  <td class="p-3 font-mono text-xs text-gray-500 space-y-0.5">
                    <p>📅 <strong>Start:</strong> {app.period_start}</p>
                    <p :if={app.is_partial} class="text-amber-700 font-semibold">
                      ⏱️ Sub-Hours: {app.partial_time_from} - {app.partial_time_to}
                    </p>
                  </td>
                  <td class="p-3 text-right space-x-2 whitespace-nowrap">
                    <button type="button" phx-click="approve_workflow" phx-value-id={app.id} class="px-3 py-1 rounded bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold shadow-xxs transition">
                      Sign Off
                    </button>
                    <button type="button" phx-click="reject_workflow" phx-value-id={app.id} class="px-3 py-1 rounded bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold transition">
                      Deny
                    </button>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@approvals)}>
                  <td colspan="4" class="p-8 text-center text-gray-400 italic">No structural adjustment workflow envelopes awaiting validation actions.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </div>
    """
  end
end
defmodule TimeclockWeb.AdminApprovalsLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if manager_or_admin?(current_user) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "approvals:queue")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "absences:queue")
      end

      {:ok,
       assign(socket,
         page_title: "Workflow Approvals Matrix",
         absences: fetch_pending_absences(current_user),
         approvals: fetch_pending_approvals(current_user)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied: Manager or Administrator privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("approve_absence", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, absence} <- Ash.get(Timeclock.Absences.Absence, id, actor: current_user),
         {:ok, updated} <- Ash.update(absence, :approve, %{}, actor: current_user) do
      enqueue_notification(updated.user_id, url(socket, ~p"/home/time-off"), "Time-Off Request Approved")
      broadcast_queue_refresh("absences:queue")

      {:noreply,
       socket
       |> put_flash(:info, "Absence request approved and workflow finalized.")
       |> assign(absences: fetch_pending_absences(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to approve absence request.")}
    end
  end

  @impl true
  def handle_event("reject_absence", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, absence} <- Ash.get(Timeclock.Absences.Absence, id, actor: current_user),
         {:ok, updated} <-
           Ash.update(absence, :deny, %{denial_reason: "Denied by manager"}, actor: current_user) do
      enqueue_notification(updated.user_id, url(socket, ~p"/home/time-off"), "Time-Off Request Denied")
      broadcast_queue_refresh("absences:queue")

      {:noreply,
       socket
       |> put_flash(:info, "Absence request denied.")
       |> assign(absences: fetch_pending_absences(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to deny absence request.")}
    end
  end

  @impl true
  def handle_event("approve_workflow", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, approval} <- Ash.get(Timeclock.Approvals.Approval, id, actor: current_user),
         {:ok, updated} <- Ash.update(approval, :approve, %{}, actor: current_user) do
      enqueue_notification(updated.user_id, url(socket, ~p"/home"), "Schedule Override Approved")
      broadcast_queue_refresh("approvals:queue")

      {:noreply,
       socket
       |> put_flash(:info, "Workflow signed off and reactor finalized.")
       |> assign(approvals: fetch_pending_approvals(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to sign off workflow request.")}
    end
  end

  @impl true
  def handle_event("reject_workflow", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, approval} <- Ash.get(Timeclock.Approvals.Approval, id, actor: current_user),
         {:ok, updated} <-
           Ash.update(approval, :deny, %{denial_reason: "Rejected by manager"}, actor: current_user) do
      enqueue_notification(updated.user_id, url(socket, ~p"/home"), "Schedule Override Rejected")
      broadcast_queue_refresh("approvals:queue")

      {:noreply,
       socket
       |> put_flash(:info, "Workflow request rejected.")
       |> assign(approvals: fetch_pending_approvals(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to reject workflow request.")}
    end
  end

  @impl true
  def handle_info(:refresh_queue, socket) do
    current_user = socket.assigns.current_user

    {:noreply,
     assign(socket,
       absences: fetch_pending_absences(current_user),
       approvals: fetch_pending_approvals(current_user)
     )}
  end

  defp fetch_pending_absences(current_user) do
    require Ash.Query

    Timeclock.Absences.Absence
    |> Ash.Query.filter(state in [:pending, :escalated])
    |> Ash.Query.sort(created_at: :asc)
    |> Ash.Query.load([:user, :absence_definition])
    |> Ash.read!(actor: current_user)
  end

  defp fetch_pending_approvals(current_user) do
    require Ash.Query

    Timeclock.Approvals.Approval
    |> Ash.Query.filter(state in [:pending, :escalated])
    |> Ash.Query.sort(created_at: :asc)
    |> Ash.Query.load([:user, :request_definition])
    |> Ash.read!(actor: current_user)
  end

  defp enqueue_notification(nil, _target_url, _subject), do: :ok

  defp enqueue_notification(user_id, target_url, subject) do
    %{
      "user_id" => user_id,
      "url" => target_url,
      "subject" => subject
    }
    |> Timeclock.Workers.EmailDeliveryWorker.new()
    |> Oban.insert()
  end

  defp broadcast_queue_refresh(topic) do
    Phoenix.PubSub.broadcast(Timeclock.PubSub, topic, :refresh_queue)
  end

  defp manager_or_admin?(%{role: role}) when role in [:admin, :manager], do: true
  defp manager_or_admin?(_), do: false

  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_dt(other), do: to_string(other)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-8">
      <div>
        <h1 class="text-3xl font-extrabold tracking-tight text-gray-900">
          Administrative Operations Matrix
        </h1>
        <p class="text-sm text-gray-500 mt-1">
          Review pending and escalated time-off requests and cross-department workflow approvals.
        </p>
      </div>

      <div class="grid grid-cols-1 gap-8">
        <!-- SECTION 1: Time-Off Absence Requests Queue -->
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
          <div class="flex items-center justify-between border-b pb-2">
            <h2 class="text-lg font-bold text-gray-900">Pending Absence Verification Queue</h2>
            <span class="px-2.5 py-0.5 rounded-full bg-gray-100 text-gray-700 text-xs font-mono font-bold">
              {Enum.count(@absences)} entries
            </span>
          </div>

          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm text-left">
              <thead>
                <tr class="bg-gray-50 text-gray-500 font-semibold">
                  <th class="p-3">Applicant</th>
                  <th class="p-3">Leave Type</th>
                  <th class="p-3">Requested Period</th>
                  <th class="p-3 text-center">State</th>
                  <th class="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr
                  :for={abs <- @absences}
                  id={"abs-verify-#{abs.id}"}
                  class={if abs.state == :escalated, do: "bg-purple-50/40", else: ""}
                >
                  <td class="p-3 font-medium text-gray-900">
                    {if abs.user, do: abs.user.email, else: "Unknown User"}
                  </td>
                  <td class="p-3">
                    <span class="px-2 py-0.5 rounded text-xs bg-amber-50 text-amber-800 border border-amber-200 font-semibold">
                      {if abs.absence_definition, do: abs.absence_definition.name, else: "Standard Request"}
                    </span>
                    <p :if={abs.reason} class="text-xs text-gray-400 italic mt-1">
                      "{abs.reason}"
                    </p>
                  </td>
                  <td class="p-3 font-mono text-xs text-gray-500">
                    {format_dt(abs.start_date)} → {format_dt(abs.end_date)}
                  </td>
                  <td class="p-3 text-center">
                    <span class={"px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase #{if abs.state == :escalated, do: "bg-purple-100 text-purple-800", else: "bg-amber-100 text-amber-800"}"}>
                      {abs.state}
                    </span>
                  </td>
                  <td class="p-3 text-right space-x-2 whitespace-nowrap">
                    <button
                      type="button"
                      phx-click="approve_absence"
                      phx-value-id={abs.id}
                      class="px-3 py-1 rounded bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition"
                    >
                      Approve
                    </button>
                    <button
                      type="button"
                      phx-click="reject_absence"
                      phx-value-id={abs.id}
                      class="px-3 py-1 rounded bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 text-xs font-bold transition"
                    >
                      Deny
                    </button>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@absences)}>
                  <td colspan="5" class="p-8 text-center text-gray-400 italic">
                    No time-off requests awaiting manager review.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- SECTION 2: Cross-Department Workflows Ledger -->
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
          <div class="flex items-center justify-between border-b pb-2">
            <h2 class="text-lg font-bold text-gray-900">Cross-Department Workflows Ledger</h2>
            <span class="px-2.5 py-0.5 rounded-full bg-gray-100 text-gray-700 text-xs font-mono font-bold">
{Enum.count(@approvals)} entries


Applicant	Definition Route	Allocation Window	State	Actions
{if app.user, do: app.user.email, else: "Unknown User"}
				No workflow requests awaiting validation.

"""
end
end