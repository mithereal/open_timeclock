defmodule TimeclockWeb.OrganizationDashboardLive do
  use TimeclockWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    orgs = Ash.read!(Timeclock.Organizations.Organization, actor: current_user)
    comps = fetch_companies(current_user)
    depts = Ash.read!(Timeclock.Organizations.Department, actor: current_user)

    if connected?(socket) do
      Enum.each(orgs, fn org ->
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "organizations:#{org.id}:companies")
      end)

      Enum.each(comps, fn comp ->
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "companies:#{comp.id}:departments")
      end)
    end

    {:ok,
     assign(socket,
       page_title: "Infrastructure Core Configuration",
       orgs: orgs,
       comps: comps,
       depts: depts,
       org_options: Enum.map(orgs, &{&1.name, &1.id}),
       comp_options: Enum.map(comps, &{&1.name, &1.id}),
       comp_form: build_comp_form(current_user),
       dept_form: build_dept_form(current_user)
     )}
  end

  @impl true
  def handle_event("validate_comp", %{"form" => params}, socket) do
    form =
      socket.assigns.comp_form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, comp_form: form)}
  end

  @impl true
  def handle_event("save_comp", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.comp_form, params: params) do
      {:ok, company} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Timeclock.PubSub, "companies:#{company.id}:departments")
        end

        comps = fetch_companies(current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Legal entity provisioned.")
         |> assign(
           comps: comps,
           comp_options: Enum.map(comps, &{&1.name, &1.id}),
           comp_form: build_comp_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, comp_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("validate_dept", %{"form" => params}, socket) do
    form =
      socket.assigns.dept_form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, dept_form: form)}
  end

  @impl true
  def handle_event("save_dept", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.dept_form, params: params) do
      {:ok, _dept} ->
        depts = Ash.read!(Timeclock.Organizations.Department, actor: current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Department unit created.")
         |> assign(
           depts: depts,
           dept_form: build_dept_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, dept_form: to_form(form))}
    end
  end

  @impl true
  def handle_info({:company_updated, company_id, _name}, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Timeclock.PubSub, "companies:#{company_id}:departments")
    end

    comps = fetch_companies(socket.assigns.current_user)

    {:noreply,
     assign(socket,
       comps: comps,
       comp_options: Enum.map(comps, &{&1.name, &1.id})
     )}
  end

  @impl true
  def handle_info({:department_updated, _dept_id, _name}, socket) do
    depts = Ash.read!(Timeclock.Organizations.Department, actor: socket.assigns.current_user)
    {:noreply, assign(socket, depts: depts)}
  end

  defp fetch_companies(current_user) do
    require Ash.Query

    Timeclock.Organizations.Company
    |> Ash.Query.sort(name: :asc)
    |> Ash.Query.load([:organization])
    |> Ash.read!(actor: current_user)
  end

  defp build_comp_form(current_user) do
    Timeclock.Organizations.Company
    |> AshPhoenix.Form.for_create(:create,
      params: %{"address" => %{"country" => "US"}},
      actor: current_user
    )
    |> to_form()
  end

  defp build_dept_form(current_user) do
    Timeclock.Organizations.Department
    |> AshPhoenix.Form.for_create(:create, actor: current_user)
    |> to_form()
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Infrastructure Core Configuration</h1>
        <p class="text-sm text-gray-500 mt-1">
          Manage parent organizations, legal company entities, and operational department units.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div :if={admin?(@current_user)} class="space-y-6">
          <div class="bg-white p-5 rounded-xl border border-gray-200 shadow-sm space-y-4">
            <h2 class="text-sm font-bold text-gray-700 uppercase tracking-wider">Legal Entity</h2>
            <.form for={@comp_form} phx-change="validate_comp" phx-submit="save_comp" class="space-y-3">
              <div>
                <.input
                  field={@comp_form[:name]}
                  type="text"
                  placeholder="Acme Logistics"
                  class="w-full text-xs"
                />
              </div>
              <div>
                <.input
                  field={@comp_form[:organization_id]}
                  type="select"
                  options={@org_options}
                  prompt="Select Parent Organization..."
                  class="w-full text-xs"
                />
              </div>
              <div>
                <.input
                  field={@comp_form[:registration_number]}
                  type="text"
                  placeholder="REG-ID (e.g. EIN-12345)"
                  class="w-full text-xs"
                />
              </div>

              <div class="border p-3 rounded-lg bg-gray-50 space-y-2">
                <span class="text-[10px] font-bold text-gray-500 uppercase">Headquarters</span>
                <.inputs_for :let={addr} field={@comp_form[:address]}>
                  <div>
                    <.input
                      field={addr[:street]}
                      type="text"
                      placeholder="Street Address"
                      class="w-full text-xs"
                    />
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <.input field={addr[:city]} type="text" placeholder="City" class="w-full text-xs" />
                    </div>
                    <div>
                      <.input field={addr[:state]} type="text" placeholder="State" class="w-full text-xs" />
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <div>
                      <.input
                        field={addr[:postal_code]}
                        type="text"
                        placeholder="ZIP / Postal"
                        class="w-full text-xs"
                      />
                    </div>
                    <div>
                      <.input
                        field={addr[:country]}
                        type="text"
                        placeholder="Country (e.g. US)"
                        maxlength="2"
                        class="w-full text-xs uppercase"
                      />
                    </div>
                  </div>
                </.inputs_for>
              </div>

              <button
                type="submit"
                class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 rounded text-xs transition"
              >
                Provision Company
              </button>
            </.form>
          </div>

          <div class="bg-white p-5 rounded-xl border border-gray-200 shadow-sm space-y-4">
            <h2 class="text-sm font-bold text-gray-700 uppercase tracking-wider">Department</h2>
            <.form for={@dept_form} phx-change="validate_dept" phx-submit="save_dept" class="space-y-3">
              <div>
                <.input
                  field={@dept_form[:name]}
                  type="text"
                  placeholder="Quality Assurance"
                  class="w-full text-xs"
                />
              </div>
              <div>
                <.input
                  field={@dept_form[:company_id]}
                  type="select"
                  options={@comp_options}
                  prompt="Select Business Unit..."
                  class="w-full text-xs"
                />
              </div>
              <button
                type="submit"
                class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 rounded text-xs transition"
              >
                Create Unit Node
              </button>
            </.form>
          </div>
        </div>

        <div class={"#{if admin?(@current_user), do: "lg:col-span-2", else: "lg:col-span-3"} bg-white p-6 rounded-xl border border-gray-200 shadow-sm"}>
          <h2 class="text-lg font-bold text-gray-900 mb-4">Operations Map Directory</h2>

          <div :if={Enum.any?(@comps)} class="space-y-4">
            <div
              :for={c <- @comps}
              class="p-4 border rounded-xl bg-gray-50/50 space-y-2"
              id={"company-card-#{c.id}"}
            >
              <div class="flex justify-between items-center font-bold">
                <div>
                  <span class="text-gray-900">{c.name}</span>
                  <span class="block text-xs text-gray-400 font-mono">
                    Code: {c.registration_number}
                  </span>
                </div>
                <span class="text-xs px-2.5 py-0.5 rounded bg-indigo-100 text-indigo-800">
{if c.organization, do: c.organization.name, else: "Root"}

{c.address.street}, {c.address.city}, {c.address.state} {c.address.postal_code}, {c.address.country}
<span
:for={d <- @depts}
:if={d.company_id == c.id}
class="px-2 py-0.5 text-xs rounded bg-blue-50 text-blue-700 border border-blue-200"
>
{d.name}



No legal entities provisioned yet.




"""
end
end