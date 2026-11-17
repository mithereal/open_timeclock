defmodule TimeclockWeb.AbsenceRequestLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "absences:#{current_user.id}")
    end

    absences = fetch_user_absences(current_user)
    definitions = Ash.read!(Timeclock.Absences.Definition, actor: current_user)
    definition_options = Enum.map(definitions, &{&1.name, &1.id})

    {:ok,
     assign(socket,
       page_title: "Time-Off Requests",
       absences: absences,
       definition_options: definition_options,
       form: build_create_form(current_user)
     )}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(normalize_datetime_params(params))
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: normalize_datetime_params(params)) do
      {:ok, _absence} ->
        {:noreply,
         socket
         |> put_flash(:info, "Time-off request submitted for approval.")
         |> assign(
           absences: fetch_user_absences(current_user),
           form: build_create_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("cancel_request", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, record} <- Ash.get(Timeclock.Absences.Absence, id, actor: current_user),
         {:ok, _cancelled} <- Ash.update(record, :cancel, %{}, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Time-off request cancelled.")
       |> assign(absences: fetch_user_absences(current_user))}
    else
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to cancel this request.")}
    end
  end

  @impl true
  def handle_info({event, _absence_id}, socket)
      when event in [:absence_approved, :absence_denied, :absence_updated] do
    {:noreply,
     socket
     |> put_flash(:info, "Your absence request status was updated.")
     |> assign(absences: fetch_user_absences(socket.assigns.current_user))}
  end

  defp fetch_user_absences(current_user) do
    require Ash.Query

    Timeclock.Absences.Absence
    |> Ash.Query.filter(user_id == ^current_user.id)
    |> Ash.Query.sort(start_date: :desc)
    |> Ash.Query.load([:absence_definition, :approved_by])
    |> Ash.read!(actor: current_user)
  end

  defp build_create_form(current_user) do
    Timeclock.Absences.Absence
    |> AshPhoenix.Form.for_create(:create, actor: current_user)
    |> to_form()
  end

  defp normalize_datetime_params(params) do
    params
    |> normalize_bound("start_date", "T00:00:00Z")
    |> normalize_bound("end_date", "T23:59:59Z")
  end

  defp normalize_bound(params, key, suffix) do
    case Map.get(params, key) do
      <<_::binary-size(10)>> = date_only -> Map.put(params, key, date_only <> suffix)
      <<_::binary-size(16)>> = datetime_local -> Map.put(params, key, datetime_local <> ":00Z")
      _ -> params
    end
  end

  defp badge_classes(:completed), do: "bg-green-100 text-green-800"
  defp badge_classes(:approved), do: "bg-green-100 text-green-800"
  defp badge_classes(:denied), do: "bg-red-100 text-red-800"
  defp badge_classes(:cancelled), do: "bg-gray-100 text-gray-600"
  defp badge_classes(:escalated), do: "bg-purple-100 text-purple-800"
  defp badge_classes(_pending), do: "bg-amber-100 text-amber-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-3xl font-extrabold tracking-tight text-gray-900">Time-Off Requests</h1>
        <p class="text-sm text-gray-500 mt-1">
          Submit leave requests, select leave classifications, and monitor manager workflow approvals.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit lg:col-span-1">
          <h2 class="text-lg font-bold text-gray-900 mb-4">File Time-Off Request</h2>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider">
                Leave Classification
              </label>
              <.input
                field={@form[:absence_definition_id]}
                type="select"
                options={@definition_options}
                prompt="Select absence category..."
                class="mt-1 block w-full rounded border-gray-300 text-sm"
              />
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  Start Date
                </label>
                <.input
                  field={@form[:start_date]}
                  type="date"
                  class="mt-1 block w-full rounded border-gray-300 text-sm shadow-sm"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider">
                  End Date
                </label>
                <.input
                  field={@form[:end_date]}
                  type="date"
                  class="mt-1 block w-full rounded border-gray-300 text-sm shadow-sm"
                />
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider">
                Justification Notes
              </label>
              <.input
                field={@form[:reason]}
                type="textarea"
                placeholder="Provide reason details..."
                rows="3"
                class="mt-1 block w-full rounded border-gray-300 text-sm shadow-sm"
              />
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded-lg text-sm transition shadow-sm"
            >
              Submit Leave Request
            </button>
          </.form>
        </div>

        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Your Absence Ledger Records</h2>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm text-left">
              <thead>
                <tr class="text-gray-500 font-medium bg-gray-50">
                  <th class="p-3">Category</th>
                  <th class="p-3">Timeframe Bounds</th>
                  <th class="p-3 text-center">Workflow State</th>
                  <th class="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 text-gray-700">
                <tr :for={abs <- @absences} id={"absence-row-#{abs.id}"}>
                  <td class="p-3 font-semibold text-gray-900">
                    {if abs.absence_definition, do: abs.absence_definition.name, else: "Standard Leave"}
                    <span
                      :if={abs.reason}
                      class="block text-xs text-gray-400 font-normal italic mt-0.5"
                    >
                      "{abs.reason}"
                    </span>
                  </td>
                  <td class="p-3 font-mono text-xs text-gray-500">
                    {Calendar.strftime(abs.start_date, "%Y-%m-%d")} → {Calendar.strftime(abs.end_date, "%Y-%m-%d")}
                  </td>
                  <td class="p-3 text-center">
                    <span class={"inline-flex items-center px-2 py-0.5 rounded text-xs font-mono font-bold uppercase tracking-wider #{badge_classes(abs.state)}"}>
                      {abs.state}
                    </span>
                  </td>
                  <td class="p-3 text-right">
                    <button
                      :if={abs.state == :pending}
                      type="button"
                      phx-click="cancel_request"
                      phx-value-id={abs.id}
                      data-confirm="Cancel this time-off request?"
                      class="text-red-600 hover:underline font-semibold text-xs"
                    >
                      Cancel
                    </button>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@absences)}>
                  <td colspan="4" class="p-8 text-center text-gray-400">
                    No time-off logs registered in your personal file tracker yet.
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
