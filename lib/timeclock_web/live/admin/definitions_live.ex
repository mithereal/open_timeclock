defmodule TimeclockWeb.Admin.DefinitionsLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if admin?(current_user) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "system:codes")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "system:statuses")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "system:tags")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "clocking_definitions")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "absence_definitions")
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "scheduling:shifts")
      end

      {:ok,
       socket
       |> assign(page_title: "System Definitions & Rules", active_tab: :codes)
       |> reload_all(current_user)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied: Administrator privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ["codes", "statuses", "clocking", "absences", "shifts"] do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("save_code", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.code_form, params: params) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Payroll code created.") |> reload_all(current_user)}

      {:error, form} ->
        {:noreply, assign(socket, code_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("save_status", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user
    params = Map.put_new(params, "icon", "hero-check-badge")

    case AshPhoenix.Form.submit(socket.assigns.status_form, params: params) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Status marker created.") |> reload_all(current_user)}

      {:error, form} ->
        {:noreply, assign(socket, status_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("save_clocking_def", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.clocking_def_form, params: params) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Clocking definition created.") |> reload_all(current_user)}

      {:error, form} ->
        {:noreply, assign(socket, clocking_def_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("save_absence_def", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user
    params = Map.put_new(params, "icon", "hero-calendar-days")

    case AshPhoenix.Form.submit(socket.assigns.absence_def_form, params: params) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Leave policy created.") |> reload_all(current_user)}

      {:error, form} ->
        {:noreply, assign(socket, absence_def_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("save_shift", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.shift_form, params: params) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Shift rule created.") |> reload_all(current_user)}

      {:error, form} ->
        {:noreply, assign(socket, shift_form: to_form(form))}
    end
  end

  @impl true
  def handle_info(_event, socket) do
    {:noreply, reload_all(socket, socket.assigns.current_user)}
  end

  defp reload_all(socket, actor) do
    codes = Ash.read!(Timeclock.System.Code, actor: actor)
    statuses = Timeclock.System.Status |> Ash.Query.load([:code]) |> Ash.read!(actor: actor)
    clocking_defs = Timeclock.Clocking.Definition |> Ash.Query.load([:code]) |> Ash.read!(actor: actor)
    absence_defs = Timeclock.Absences.Definition |> Ash.Query.load([:code]) |> Ash.read!(actor: actor)
    shifts = Ash.read!(Timeclock.Scheduling.Shift, actor: actor)

    code_options = Enum.map(codes, &{&1.code, &1.id})

    assign(socket,
      codes: codes,
      statuses: statuses,
      clocking_defs: clocking_defs,
      absence_defs: absence_defs,
      shifts: shifts,
      code_options: code_options,
      code_form: Timeclock.System.Code |> AshPhoenix.Form.for_create(:create, actor: actor) |> to_form(),
      status_form: Timeclock.System.Status |> AshPhoenix.Form.for_create(:create, actor: actor) |> to_form(),
      clocking_def_form: Timeclock.Clocking.Definition |> AshPhoenix.Form.for_create(:create, actor: actor) |> to_form(),
      absence_def_form: Timeclock.Absences.Definition |> AshPhoenix.Form.for_create(:create, actor: actor) |> to_form(),
      shift_form: Timeclock.Scheduling.Shift |> AshPhoenix.Form.for_create(:create, actor: actor) |> to_form()
    )
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">System Definitions & Rules</h1>
          <p class="text-sm text-gray-500 mt-1">
            Configure payroll codes, punch statuses, kiosk definitions, leave policies, and shift templates.
          </p>
        </div>

        <div class="inline-flex flex-wrap rounded-lg border border-gray-200 bg-gray-50 p-1 text-xs font-semibold">
          <button
            :for={{key, label} <- [
              {:codes, "Payroll Codes"},
              {:statuses, "Statuses"},
              {:clocking, "Punch Types"},
              {:absences, "Leave Policies"},
              {:shifts, "Shift Templates"}
            ]}
            type="button"
            phx-click="switch_tab"
            phx-value-tab={key}
            class={"px-3 py-1.5 rounded-md transition #{if @active_tab == key, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
          >
            {label}
          </button>
        </div>
      </div>

      <!-- TAB 1: PAYROLL CODES -->
      <div :if={@active_tab == :codes} class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit">
          <h2 class="text-lg font-bold text-gray-900 mb-4">Add Payroll Code</h2>
          <.form for={@code_form} phx-submit="save_code" class="space-y-4">
            <.input field={@code_form[:code]} type="text" placeholder="e.g. REG, OT_15, PTO" class="w-full text-sm uppercase" />
            <button type="submit" class="w-full bg-indigo-600 text-white font-bold py-2 rounded text-sm">
              Create Code
            </button>
          </.form>
        </div>

        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Configured Payroll Codes</h2>
          <div class="flex flex-wrap gap-2">
            <span
              :for={c <- @codes}
              class="px-3 py-1.5 rounded-lg bg-slate-100 border border-slate-200 font-mono text-xs font-bold text-slate-800"
            >
              {c.code}
            </span>
            <p :if={Enum.empty?(@codes)} class="text-sm text-gray-400">No codes configured yet.</p>
          </div>
        </div>
      </div>

      <!-- TAB 2: STATUSES -->
      <div :if={@active_tab == :statuses} class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit">
          <h2 class="text-lg font-bold text-gray-900 mb-4">Add Status Marker</h2>
          <.form for={@status_form} phx-submit="save_status" class="space-y-3">
            <.input field={@status_form[:name]} type="text" placeholder="Status Name (e.g. On Duty)" class="w-full text-sm" />
            <.input field={@status_form[:code_id]} type="select" options={@code_options} prompt="Link Payroll Code..." class="w-full text-sm" />
            <.input field={@status_form[:presence_status]} type="select" options={["present", "absent", "neutral", "on_break"]} class="w-full text-sm" />
            <.input field={@status_form[:paid_time_status]} type="select" options={["paid", "unpaid", "partial"]} class="w-full text-sm" />
            <.input field={@status_form[:color]} type="text" value="#10B981" placeholder="#10B981" class="w-full text-sm font-mono" />
            <button type="submit" class="w-full bg-indigo-600 text-white font-bold py-2 rounded text-sm">
              Create Status
            </button>
          </.form>
        </div>

        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm overflow-x-auto">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">System Status Markers</h2>
          <table class="min-w-full divide-y divide-gray-200 text-sm text-left">
            <thead>
              <tr class="bg-gray-50 text-gray-500 font-semibold">
                <th class="p-3">Name</th>
                <th class="p-3">Code</th>
                <th class="p-3">Presence</th>
                <th class="p-3">Paid State</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr :for={st <- @statuses}>
                <td class="p-3 font-bold text-gray-900">{st.name}</td>
                <td class="p-3 font-mono text-xs">{if st.code, do: st.code.code, else: "—"}</td>
{st.presence_status}
{st.paid_time_status}
<div :if={@active_tab == :clocking} class="grid grid-cols-1 lg:grid-cols-3 gap-6">

Add Punch Definition
<.form for={@clocking_def_form} phx-submit="save_clocking_def" class="space-y-3">
<.input field={@clocking_def_form[:name]} type="text" placeholder="e.g. Clock In, Start Break" class="w-full text-sm" />
<.input field={@clocking_def_form[:type]} type="number" value="1" placeholder="Numeric Type (0..50)" class="w-full text-sm" />
<.input field={@clocking_def_form[:code_id]} type="select" options={@code_options} prompt="Link Payroll Code..." class="w-full text-sm" />
<.input field={@clocking_def_form[:restriction_type]} type="select" options={["none", "web_only", "kiosk_only", "geofence_required", "admin_only"]} class="w-full text-sm" />

Create Punch Type

</.form>
Configured Punch Types

Name	Code	Restriction
{cd.name}
	{if cd.code, do: cd.code.code, else: "—"}	{cd.restriction_type}

<div :if={@active_tab == :absences} class="grid grid-cols-1 lg:grid-cols-3 gap-6">

Add Leave Policy
<.form for={@absence_def_form} phx-submit="save_absence_def" class="space-y-3">
<.input field={@absence_def_form[:name]} type="text" placeholder="e.g. Annual PTO, Sick Leave" class="w-full text-sm" />
<.input field={@absence_def_form[:type]} type="text" value="paid_time_off" placeholder="Category Type" class="w-full text-sm" />
<.input field={@absence_def_form[:code_id]} type="select" options={@code_options} prompt="Link Payroll Code..." class="w-full text-sm" />

<.input field={@absence_def_form[:max_days_per_year]} type="number" value="20" placeholder="Max Days/Yr" class="w-full text-sm" />
<.input field={@absence_def_form[:fraction]} type="number" value="100" placeholder="Pay % (1-100)" class="w-full text-sm" />

<.input field={@absence_def_form[:description]} type="textarea" rows="2" placeholder="Policy summary..." class="w-full text-sm" />

Create Leave Policy

</.form>
Active Leave Policies

Policy Name	Code	Allowance	Pay %
{ad.name}
	{if ad.code, do: ad.code.code, else: "—"}	{ad.max_days_per_year} days	{ad.fraction}%

<div :if={@active_tab == :shifts} class="grid grid-cols-1 lg:grid-cols-3 gap-6">

Add Shift Template
<.form for={@shift_form} phx-submit="save_shift" class="space-y-3">
<.input field={@shift_form[:name]} type="text" placeholder="e.g. Morning Shift (08:00-16:00)" class="w-full text-sm" />

Start Time
<.input field={@shift_form[:start_time]} type="time" class="w-full text-sm" />

End Time
<.input field={@shift_form[:end_time]} type="time" class="w-full text-sm" />



Create Shift Template

</.form>
Shift Rule Templates

Shift Name	Window	Overnight
{sh.name}
	{sh.start_time} → {sh.end_time}	{if sh.is_overnight, do: "Yes", else: "No"}

"""
end
end