defmodule TimeclockWeb.ClockingTerminalLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "clockings:live")
    end

    definitions = Ash.read!(Timeclock.Clocking.Definition, actor: current_user)
    statuses = Ash.read!(Timeclock.System.Status, actor: current_user)

    user_options =
      if kiosk_or_manager?(current_user) do
        Timeclock.Accounts.User
        |> Ash.Query.load([:account])
        |> Ash.read!(actor: current_user)
        |> Enum.map(fn u ->
          label =
            if u.account do
              "#{u.account.first_name} #{u.account.last_name}"
            else
              to_string(u.email)
            end

          {label, u.id}
        end)
      else
        []
      end

    {:ok,
     assign(socket,
       page_title: "Workforce Kiosk Terminal",
       clockings: fetch_clockings(current_user),
       user_options: user_options,
       definition_options: Enum.map(definitions, &{&1.name, &1.id}),
       status_options: Enum.map(statuses, &{&1.name, &1.id}),
       form: build_punch_form(current_user),
       has_geo: false
     )}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    params = Map.put_new(params, "has_geo_location", "false")
    has_geo = params["has_geo_location"] in ["true", true]

    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form, has_geo: has_geo)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user
    params = Map.put_new(params, "has_geo_location", "false")

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _clocking} ->
        {:noreply,
         socket
         |> put_flash(:info, "Punch captured.")
         |> assign(
           clockings: fetch_clockings(current_user),
           form: build_punch_form(current_user),
           has_geo: false
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_info({:punch_recorded, _id, _user_id, _punched_at}, socket) do
    {:noreply, assign(socket, clockings: fetch_clockings(socket.assigns.current_user))}
  end

  defp fetch_clockings(current_user) do
    require Ash.Query

    Timeclock.Clocking.Clocking
    |> Ash.Query.sort(punched_at: :desc)
    |> Ash.Query.load([:user, :definition, :status])
    |> Ash.Query.limit(15)
    |> Ash.read!(actor: current_user)
  end

  defp build_punch_form(current_user) do
    action = if kiosk_or_manager?(current_user), do: :insert_from_kiosk, else: :insert_from_web

    Timeclock.Clocking.Clocking
    |> AshPhoenix.Form.for_create(action, actor: current_user)
    |> to_form()
  end

  defp kiosk_or_manager?(%{role: role}) when role in [:admin, :manager, :kiosk], do: true
  defp kiosk_or_manager?(_), do: false

  defp format_punch_time(%{punched_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%H:%M:%S UTC")
  defp format_punch_time(%{created_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%H:%M:%S UTC")
  defp format_punch_time(_), do: "--:--:--"

  defp workflow_badge(:verified), do: "bg-green-100 text-green-800"
  defp workflow_badge(:flagged), do: "bg-red-100 text-red-800"
  defp workflow_badge(:voided), do: "bg-gray-100 text-gray-500"
  defp workflow_badge(_), do: "bg-amber-100 text-amber-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Workforce Kiosk Terminal</h1>
        <p class="text-sm text-gray-500 mt-1">
          Record attendance punches and monitor live verification events across terminals.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Record Attendance</h2>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div :if={kiosk_or_manager?(@current_user)}>
              <label class="block text-xs font-bold text-gray-500 uppercase">Employee</label>
              <.input
                field={@form[:user_id]}
                type="select"
                options={@user_options}
                prompt="Select employee profile..."
                class="mt-1 block w-full rounded border-gray-300 text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-bold text-gray-500 uppercase">Punch Action</label>
              <.input
                field={@form[:definition_id]}
                type="select"
                options={@definition_options}
                prompt="Select punch type..."
                class="mt-1 block w-full rounded border-gray-300 text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-bold text-gray-500 uppercase">Status</label>
              <.input
                field={@form[:status_id]}
                type="select"
                options={@status_options}
                prompt="Select status..."
                class="mt-1 block w-full rounded border-gray-300 text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-bold text-gray-500 uppercase">Comment</label>
              <.input
                field={@form[:comment]}
                type="text"
                placeholder="Shift notes..."
                class="mt-1 block w-full rounded border-gray-300 text-sm"
              />
            </div>

            <div class="p-3 bg-gray-50 rounded-lg space-y-3">
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold text-gray-700 uppercase">Attach GPS Coordinates</span>
                <.input field={@form[:has_geo_location]} type="checkbox" class="rounded text-indigo-600" />
              </div>

              <div :if={@has_geo} class="grid grid-cols-2 gap-2 pt-2 border-t border-gray-200">
                <div>
                  <.input
                    field={@form[:latitude]}
                    type="number"
                    step="0.000001"
                    placeholder="Latitude (-90..90)"
                    class="w-full text-xs"
                  />
                </div>
                <div>
                  <.input
                    field={@form[:longitude]}
                    type="number"
                    step="0.000001"
                    placeholder="Longitude (-180..180)"
                    class="w-full text-xs"
                  />
                </div>
              </div>
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 text-white font-semibold py-2 rounded shadow hover:bg-indigo-700 transition"
            >
              Log Clocking
            </button>
          </.form>
        </div>

        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Live Activity Streams</h2>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm text-left">
              <thead>
                <tr class="text-gray-500 font-medium bg-gray-50">
                  <th class="p-3">Employee</th>
                  <th class="p-3">Action</th>
                  <th class="p-3">Status</th>
                  <th class="p-3 text-center">Verification</th>
                  <th class="p-3 text-right">Timestamp</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={c <- @clockings} id={"clocking-row-#{c.id}"}>
                  <td class="p-3 font-medium">
                    {if c.user, do: c.user.email, else: "System"}
                  </td>
                  <td class="p-3">
                    {if c.definition, do: c.definition.name, else: "Punch"}
                  </td>
                  <td class="p-3">
                    <span class="px-2 py-0.5 text-xs bg-blue-100 rounded text-blue-800">
                      {if c.status, do: c.status.name, else: "Default"}
                    </span>
                  </td>
                  <td class="p-3 text-center">
                    <span class={"px-2 py-0.5 text-[10px] font-mono font-bold uppercase rounded #{workflow_badge(c.state)}"}>
                      {c.state}
                    </span>
                  </td>
                  <td class="p-3 text-right font-mono text-xs text-gray-500">
                    {format_punch_time(c)}
                  </td>
                </tr>
                <tr :if={Enum.empty?(@clockings)}>
                  <td colspan="5" class="p-8 text-center text-gray-400">
                    No clocking punches recorded yet.
                  </td>
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
