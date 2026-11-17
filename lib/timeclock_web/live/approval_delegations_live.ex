defmodule TimeclockWeb.ApprovalDelegationsLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if manager_or_admin?(current_user) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "approvals:delegations:#{current_user.id}")
      end

      users =
        Timeclock.Accounts.User
        |> Ash.Query.filter(id != ^current_user.id and status == :active)
        |> Ash.read!(actor: current_user)

      {:ok,
       assign(socket,
         page_title: "Approval Delegations",
         delegations: fetch_delegations(current_user),
         delegate_options: Enum.map(users, &{to_string(&1.email), &1.id}),
         form: build_create_form(current_user)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied: Manager or Administrator privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(normalize_datetimes(params))
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: normalize_datetimes(params)) do
      {:ok, _delegation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Approval delegation activated.")
         |> assign(
           delegations: fetch_delegations(current_user),
           form: build_create_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, delegation} <- Ash.get(Timeclock.Approvals.PermissionDelegation, id, actor: current_user),
         {:ok, _revoked} <- Ash.update(delegation, :revoke, %{}, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Approval delegation revoked.")
       |> assign(delegations: fetch_delegations(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to revoke delegation.")}
    end
  end

  @impl true
  def handle_info({:delegation_updated, _id, _state}, socket) do
    {:noreply, assign(socket, delegations: fetch_delegations(socket.assigns.current_user))}
  end

  defp fetch_delegations(current_user) do
    Timeclock.Approvals.PermissionDelegation
    |> Ash.Query.sort(created_at: :desc)
    |> Ash.Query.load([:user, :delegated_user])
    |> Ash.read!(actor: current_user)
  end

  defp build_create_form(current_user) do
    Timeclock.Approvals.PermissionDelegation
    |> AshPhoenix.Form.for_create(:create, actor: current_user)
    |> to_form()
  end

  defp normalize_datetimes(params) do
    params
    |> append_z("starts_at")
    |> append_z("expires_at")
  end

  defp append_z(params, key) do
    case Map.get(params, key) do
      <<_::binary-size(16)>> = dt -> Map.put(params, key, dt <> ":00Z")
      _ -> params
    end
  end

  defp manager_or_admin?(%{role: role}) when role in [:admin, :manager], do: true
  defp manager_or_admin?(_), do: false

  defp state_badge(:active), do: "bg-green-100 text-green-800"
  defp state_badge(:expired), do: "bg-gray-100 text-gray-500"
  defp state_badge(:revoked), do: "bg-red-100 text-red-800"
  defp state_badge(_), do: "bg-amber-100 text-amber-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-6xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Approval Authority Delegations</h1>
        <p class="text-sm text-gray-500 mt-1">
          Temporarily delegate approval sign-off authority to a colleague with automatic scheduled expiration.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit">
          <h2 class="text-lg font-bold text-gray-900 mb-4">Grant Delegation</h2>
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">
                Delegate To User
              </label>
              <.input
                field={@form[:delegated_user_id]}
                type="select"
                options={@delegate_options}
                prompt="Select backup approver..."
                class="w-full text-sm"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Starts At</label>
              <.input field={@form[:starts_at]} type="datetime-local" class="w-full text-sm" />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">
                Expires At (Auto-Revokes)
              </label>
              <.input field={@form[:expires_at]} type="datetime-local" class="w-full text-sm" />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Reason</label>
              <.input
                field={@form[:reason]}
                type="text"
                placeholder="e.g. Annual PTO coverage"
                class="w-full text-sm"
              />
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded-lg text-sm transition"
            >
              Activate Delegation
            </button>
          </.form>
        </div>

        <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Delegation Registry</h2>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 text-sm text-left">
              <thead>
                <tr class="bg-gray-50 text-gray-500 font-semibold">
                  <th class="p-3">Grantor</th>
                  <th class="p-3">Delegate</th>
                  <th class="p-3">Window</th>
                  <th class="p-3 text-center">State</th>
                  <th class="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={del <- @delegations} id={"del-#{del.id}"}>
                  <td class="p-3 font-medium text-gray-900">
                    {if del.user, do: del.user.email, else: "Grantor"}
                  </td>
                  <td class="p-3 font-medium text-indigo-700">
                    {if del.delegated_user, do: del.delegated_user.email, else: "Delegate"}
                    <p :if={del.reason} class="text-xs text-gray-400 italic">"{del.reason}"</p>
                  </td>
                  <td class="p-3 font-mono text-xs text-gray-500">
                    <div>From: {Calendar.strftime(del.starts_at, "%Y-%m-%d %H:%M")}</div>
                    <div>
                      Until: {if del.expires_at, do: Calendar.strftime(del.expires_at, "%Y-%m-%d %H:%M"), else: "Indefinite"}
                    </div>
                  </td>
                  <td class="p-3 text-center">
                    <span class={"px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase #{state_badge(del.state)}"}>
                      {del.state}
                    </span>
                  </td>
                  <td class="p-3 text-right">
                    <button
                      :if={del.state == :active && del.user_id == @current_user.id}
                      type="button"
                      phx-click="revoke"
                      phx-value-id={del.id}
                      data-confirm="Revoke this approval delegation immediately?"
                      class="text-xs font-bold text-red-600 hover:underline"
                    >
                      Revoke
                    </button>
                  </td>
                </tr>
                <tr :if={Enum.empty?(@delegations)}>
                  <td colspan="5" class="p-8 text-center text-gray-400">
                    No approval delegations configured.
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