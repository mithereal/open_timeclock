defmodule TimeclockWeb.AdjustmentsLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    definitions = Ash.read!(Timeclock.Adjustments.Definition, actor: current_user)
    statuses = Ash.read!(Timeclock.System.Status, actor: current_user)

    accounts =
      if manager_or_admin?(current_user) do
        Ash.read!(Timeclock.Accounts.Account, actor: current_user)
      else
        Timeclock.Accounts.Account
        |> Ash.Query.filter(user_id == ^current_user.id)
        |> Ash.read!(actor: current_user)
      end

    if connected?(socket) do
      Enum.each(accounts, fn acc ->
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "adjustments:#{acc.id}")
      end)
    end

    default_account_id =
      case accounts do
        [first | _] -> first.id
        [] -> nil
      end

    default_status_id =
      case statuses do
        [first | _] -> first.id
        [] -> nil
      end

    {:ok,
     assign(socket,
       page_title: "Hour & Balance Adjustments",
       adjustments: fetch_adjustments(current_user),
       definition_options: Enum.map(definitions, &{&1.name, &1.id}),
       account_options: Enum.map(accounts, &{"#{&1.first_name} #{&1.last_name} (#{&1.custom_id})", &1.id}),
       status_options: Enum.map(statuses, &{&1.name, &1.id}),
       default_account_id: default_account_id,
       default_status_id: default_status_id,
       is_partial: false,
       form: build_create_form(current_user, default_account_id, default_status_id)
     )}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    params = Map.put_new(params, "is_partial", "false")
    is_partial = params["is_partial"] in ["true", true]

    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form, is_partial: is_partial)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    params =
      params
      |> Map.put_new("is_partial", "false")
      |> Map.put_new("icon", "hero-adjustments-horizontal")

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _adjustment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Adjustment submitted.")
         |> assign(
           adjustments: fetch_adjustments(current_user),
           is_partial: false,
           form:
             build_create_form(
               current_user,
               socket.assigns.default_account_id,
               socket.assigns.default_status_id
             )
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("transition", %{"id" => id, "action" => action_str}, socket)
      when action_str in ["approve", "deny", "cancel"] do
    current_user = socket.assigns.current_user
    action = String.to_existing_atom(action_str)

    attrs = if action == :deny, do: %{denial_reason: "Denied by reviewer"}, else: %{}

    with {:ok, adj} <- Ash.get(Timeclock.Adjustments.Adjustment, id, actor: current_user),
         {:ok, _updated} <- Ash.update(adj, action, attrs, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Adjustment #{action_str} processed.")
       |> assign(adjustments: fetch_adjustments(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to process adjustment transition.")}
    end
  end

  @impl true
  def handle_info({:adjustment_applied, _id, _value}, socket) do
    {:noreply, assign(socket, adjustments: fetch_adjustments(socket.assigns.current_user))}
  end

  defp fetch_adjustments(current_user) do
    Timeclock.Adjustments.Adjustment
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.Query.load([:account, :definition, :status])
    |> Ash.Query.limit(50)
    |> Ash.read!(actor: current_user)
  end

  defp build_create_form(current_user, default_account_id, default_status_id) do
    action = if manager_or_admin?(current_user), do: :create_admin, else: :create

    defaults =
      %{
        "account_id" => default_account_id,
        "status_id" => default_status_id,
        "icon" => "hero-adjustments-horizontal"
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    Timeclock.Adjustments.Adjustment
    |> AshPhoenix.Form.for_create(action, params: defaults, actor: current_user)
    |> to_form()
  end

  defp manager_or_admin?(%{role: role}) when role in [:admin, :manager], do: true
  defp manager_or_admin?(_), do: false

  defp state_badge(:completed), do: "bg-green-100 text-green-800"
  defp state_badge(:approved), do: "bg-green-100 text-green-800"
  defp state_badge(:denied), do: "bg-red-100 text-red-800"
  defp state_badge(:cancelled), do: "bg-gray-100 text-gray-500"
  defp state_badge(:escalated), do: "bg-purple-100 text-purple-800"
  defp state_badge(_), do: "bg-amber-100 text-amber-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Hour & Balance Adjustments</h1>
        <p class="text-sm text-gray-500 mt-1">
          Submit manual time/accrual adjustments, specify sub-day intervals, and review workflow sign-offs.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit">
          <h2 class="text-lg font-bold text-gray-900 mb-4">
            {if manager_or_admin?(@current_user), do: "Issue Authentic Adjustment", else: "Request Adjustment"}
          </h2>

          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Account</label>
              <.input
                field={@form[:account_id]}
                type="select"
                options={@account_options}
                prompt="Select employee account..."
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">
                Adjustment Type
              </label>
              <.input
                field={@form[:definition_id]}
                type="select"
                options={@definition_options}
                prompt="Select adjustment rule..."
                class="w-full text-sm"
              />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">
                  Value (+/- Hours/Days)
                </label>
                <.input
                  field={@form[:value]}
                  type="number"
                  step="0.25"
                  placeholder="e.g. 2.5"
                  class="w-full text-sm"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Status</label>
                <.input
                  field={@form[:status_id]}
                  type="select"
                  options={@status_options}
                  class="w-full text-sm"
                />
              </div>
            </div>

            <div class="p-3 bg-gray-50 rounded-lg space-y-3">
              <div class="flex items-center justify-between">
                <span class="text-xs font-semibold text-gray-700 uppercase">Partial Day Window</span>
                <.input field={@form[:is_partial]} type="checkbox" class="rounded text-indigo-600" />
              </div>

              <div :if={@is_partial} class="grid grid-cols-3 gap-2 pt-2 border-t border-gray-200">
                <div>
                  <label class="block text-[10px] font-bold text-gray-500 uppercase">From</label>
                  <.input field={@form[:partial_time_from]} type="time" class="w-full text-xs" />
                </div>
                <div>
                  <label class="block text-[10px] font-bold text-gray-500 uppercase">To</label>
                  <.input field={@form[:partial_time_to]} type="time" class="w-full text-xs" />
                </div>
                <div>
                  <label class="block text-[10px] font-bold text-gray-500 uppercase">Hours</label>
                  <.input
                    field={@form[:partial_time_duration]}
                    type="number"
                    step="0.25"
                    class="w-full text-xs"
                  />
                </div>
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Comment</label>
              <.input
                field={@form[:comment]}
                type="textarea"
                rows="2"
                placeholder="Reason for adjustment..."
                class="w-full text-sm"
              />
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded-lg text-sm transition"
            >
              {if manager_or_admin?(@current_user), do: "Apply Authentic Adjustment", else: "Submit Request"}
            </button>
          </.form>
        </div>

        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
Adjustments Ledger

Employee	Rule	Value	State	Actions
{if adj.account, do: "#{adj.account.first_name} #{adj.account.last_name}", else: "Account"}
	{if adj.definition, do: adj.definition.name, else: "Adjustment"}	{if adj.value >= 0, do: "+#{adj.value}", else: adj.value}		
No adjustments recorded yet.

"""
end
end