defmodule TimeclockWeb.Admin.AccountsLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if admin?(current_user) do
      departments = Ash.read!(Timeclock.Organizations.Department, actor: current_user)
      users = fetch_users(current_user)

      if connected?(socket) do
        Enum.each(users, fn u ->
          Phoenix.PubSub.subscribe(Timeclock.PubSub, "accounts:users:#{u.id}")
        end)

        Enum.each(departments, fn d ->
          Phoenix.PubSub.subscribe(Timeclock.PubSub, "departments:#{d.id}:employees")
          Phoenix.PubSub.subscribe(Timeclock.PubSub, "departments:#{d.id}:managers")
        end)
      end

      {:ok,
       assign(socket,
         page_title: "Workforce Accounts & Roles",
         active_tab: :accounts,
         users: users,
         accounts: fetch_accounts(current_user),
         employees: fetch_employees(current_user),
         managers: fetch_managers(current_user),
         user_options: Enum.map(users, &{to_string(&1.email), &1.id}),
         dept_options: Enum.map(departments, &{&1.name, &1.id}),
         account_form: build_account_form(current_user),
         employee_form: build_employee_form(current_user),
         manager_form: build_manager_form(current_user)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied: Administrator privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ["accounts", "employees", "managers"] do
    {:noreply, assign(socket, active_tab: String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("validate_account", %{"form" => params}, socket) do
    form =
      socket.assigns.account_form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, account_form: form)}
  end

  @impl true
  def handle_event("save_account", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.account_form, params: params) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee account provisioned.")
         |> assign(
           accounts: fetch_accounts(current_user),
           account_form: build_account_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, account_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("account_lifecycle", %{"id" => id, "action" => action_str}, socket)
      when action_str in ["suspend", "reactivate", "archive"] do
    current_user = socket.assigns.current_user
    action = String.to_existing_atom(action_str)

    with {:ok, account} <- Ash.get(Timeclock.Accounts.Account, id, actor: current_user),
         {:ok, _updated} <- Ash.update(account, action, %{}, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Account #{action_str} completed.")
       |> assign(accounts: fetch_accounts(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to update account lifecycle state.")}
    end
  end

  @impl true
  def handle_event("validate_employee", %{"form" => params}, socket) do
    form =
      socket.assigns.employee_form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, employee_form: form)}
  end

  @impl true
  def handle_event("save_employee", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.employee_form, params: params) do
      {:ok, _employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "Employee roster record created.")
         |> assign(
           employees: fetch_employees(current_user),
           employee_form: build_employee_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, employee_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("validate_manager", %{"form" => params}, socket) do
    form =
      socket.assigns.manager_form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, manager_form: form)}
  end

  @impl true
  def handle_event("save_manager", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.manager_form, params: params) do
      {:ok, _manager} ->
        {:noreply,
         socket
         |> put_flash(:info, "Department manager assigned.")
         |> assign(
           managers: fetch_managers(current_user),
           manager_form: build_manager_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, manager_form: to_form(form))}
    end
  end

  @impl true
  def handle_event("remove_manager", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, mgr} <- Ash.get(Timeclock.Accounts.Manager, id, actor: current_user),
         :ok <- Ash.destroy(mgr, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Department manager removed.")
       |> assign(managers: fetch_managers(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to remove department manager.")}
    end
  end

  @impl true
  def handle_event("update_user_role", %{"user_id" => user_id, "role" => role_str}, socket)
      when role_str in ["admin", "manager", "employee", "kiosk"] do
    current_user = socket.assigns.current_user
    role = String.to_existing_atom(role_str)

    if user_id == current_user.id and role != :admin do
      {:noreply, put_flash(socket, :error, "Cannot downgrade your own administrator role.")}
    else
      with {:ok, user} <- Ash.get(Timeclock.Accounts.User, user_id, actor: current_user),
           {:ok, _updated} <- Ash.update(user, :update_role, %{role: role}, actor: current_user) do
        {:noreply,
         socket
         |> put_flash(:info, "User role updated to #{role_str}.")
         |> assign(users: fetch_users(current_user))}
      else
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Unable to update user role.")}
      end
    end
  end

  @impl true
  def handle_info(_pubsub_event, socket) do
    current_user = socket.assigns.current_user

    {:noreply,
     assign(socket,
       users: fetch_users(current_user),
       accounts: fetch_accounts(current_user),
       employees: fetch_employees(current_user),
       managers: fetch_managers(current_user)
     )}
  end

  defp fetch_users(actor) do
    Timeclock.Accounts.User
    |> Ash.Query.sort(email: :asc)
    |> Ash.read!(actor: actor)
  end

  defp fetch_accounts(actor) do
    Timeclock.Accounts.Account
    |> Ash.Query.sort(last_name: :asc)
    |> Ash.Query.load([:user])
    |> Ash.read!(actor: actor)
  end

  defp fetch_employees(actor) do
    Timeclock.Accounts.Employee
    |> Ash.Query.sort(hired_at: :desc)
    |> Ash.Query.load([:user, :department])
    |> Ash.read!(actor: actor)
  end

  defp fetch_managers(actor) do
    Timeclock.Accounts.Manager
    |> Ash.Query.load([:user, :department])
    |> Ash.read!(actor: actor)
  end

  defp build_account_form(actor) do
    Timeclock.Accounts.Account
    |> AshPhoenix.Form.for_create(:create, actor: actor)
    |> to_form()
  end

  defp build_employee_form(actor) do
    Timeclock.Accounts.Employee
    |> AshPhoenix.Form.for_create(:create, actor: actor)
    |> to_form()
  end

  defp build_manager_form(actor) do
    Timeclock.Accounts.Manager
    |> AshPhoenix.Form.for_create(:create, actor: actor)
    |> to_form()
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  defp state_badge(:active), do: "bg-green-100 text-green-800"
  defp state_badge(:suspended), do: "bg-amber-100 text-amber-800"
  defp state_badge(:archived), do: "bg-gray-100 text-gray-500"
  defp state_badge(:terminated), do: "bg-red-100 text-red-800"
  defp state_badge(_), do: "bg-blue-100 text-blue-800"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Workforce Accounts & Access Control</h1>
          <p class="text-sm text-gray-500 mt-1">
            Provision employee profiles, assign kiosk PINs, manage department rosters, and configure user roles.
          </p>
        </div>

        <div class="inline-flex rounded-lg border border-gray-200 bg-gray-50 p-1 text-xs font-semibold">
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="accounts"
            class={"px-3 py-1.5 rounded-md transition #{if @active_tab == :accounts, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
          >
            Accounts & Kiosk PINs
          </button>
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="employees"
            class={"px-3 py-1.5 rounded-md transition #{if @active_tab == :employees, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
          >
            Department Roster
          </button>
          <button
            type="button"
            phx-click="switch_tab"
            phx-value-tab="managers"
            class={"px-3 py-1.5 rounded-md transition #{if @active_tab == :managers, do: "bg-white text-indigo-600 shadow-sm", else: "text-gray-600"}"}
          >
            Managers & RBAC
          </button>
        </div>
      </div>

      <!-- TAB 1: ACCOUNTS & KIOSK PINS -->
      <div :if={@active_tab == :accounts} class="grid grid-cols-1 lg:grid-cols-3 gap-6">
Use code with caution.
Provision Account
<.form for={@account_form} phx-change="validate_account" phx-submit="save_account" class="space-y-3">

<.input field={@account_form[:first_name]} type="text" placeholder="First Name" class="w-full text-xs" />
<.input field={@account_form[:last_name]} type="text" placeholder="Last Name" class="w-full text-xs" />

<.input field={@account_form[:email]} type="email" placeholder="employee@company.com" class="w-full text-xs" />

<.input field={@account_form[:custom_id]} type="text" placeholder="Employee ID (EMP-01)" class="w-full text-xs" />
<.input field={@account_form[:assigned_pin]} type="number" placeholder="Kiosk PIN (1000-999999)" class="w-full text-xs" />


<.input field={@account_form[:birth_date]} type="date" class="w-full text-xs" />
<.input field={@account_form[:gender]} type="text" placeholder="Gender" class="w-full text-xs" />

<.input field={@account_form[:mobile]} type="text" placeholder="Mobile Phone" class="w-full text-xs" />
<.input field={@account_form[:address]} type="text" placeholder="Street Address" class="w-full text-xs" />

<.input field={@account_form[:city]} type="text" placeholder="City" class="w-full text-xs" />
<.input field={@account_form[:state]} type="text" placeholder="State" class="w-full text-xs" />

<.input
field={@account_form[:user_id]}
type="select"
options={@user_options}
prompt="Link Login Identity (Optional)"
class="w-full text-xs"
/>

Create Account Profile

</.form>
Account Directory

Employee	Custom ID	Kiosk PIN	State	Lifecycle
	{acc.custom_id}	••••		
No accounts provisioned yet.

<div :if={@active_tab == :employees} class="grid grid-cols-1 lg:grid-cols-3 gap-6">

Assign Employee to Department
<.form for={@employee_form} phx-change="validate_employee" phx-submit="save_employee" class="space-y-4">
<.input field={@employee_form[:user_id]} type="select" options={@user_options} prompt="Select User..." class="w-full text-sm" />
<.input field={@employee_form[:department_id]} type="select" options={@dept_options} prompt="Select Department..." class="w-full text-sm" />
<.input field={@employee_form[:position]} type="text" placeholder="Position Title (e.g. Shift Lead)" class="w-full text-sm" />
<.input field={@employee_form[:hired_at]} type="date" class="w-full text-sm" />

Assign Employee

</.form>
Active Department Roster

User	Department	Position	State
{if emp.user, do: emp.user.email, else: "User"}
	{if emp.department, do: emp.department.name, else: "Dept"}	{emp.position}	
No employees assigned to departments yet.

<div :if={@active_tab == :managers} class="grid grid-cols-1 lg:grid-cols-3 gap-6">

Assign Department Manager
<.form for={@manager_form} phx-change="validate_manager" phx-submit="save_manager" class="space-y-4">
<.input field={@manager_form[:user_id]} type="select" options={@user_options} prompt="Select Manager User..." class="w-full text-sm" />
<.input field={@manager_form[:department_id]} type="select" options={@dept_options} prompt="Select Department..." class="w-full text-sm" />

Grant Department Authority

</.form>
Assigned Managers
<div :for={mgr <- @managers} class="p-2.5 rounded-lg bg-slate-50 border flex items-center justify-between text-xs">

{if mgr.user, do: mgr.user.email, else: "Manager"}
{if mgr.department, do: mgr.department.name, else: "Department"}


Remove



User Access Roles

Email	Status	Current Role	Assign Role
{u.email}
	{u.status}		

"""
end
end