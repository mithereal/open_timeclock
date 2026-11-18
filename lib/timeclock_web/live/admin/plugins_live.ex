defmodule TimeclockWeb.Admin.PluginsLive do
  use TimeclockWeb, :live_view
  require Ash.Query

  @hook_options [
    {"Punch Before Verify (punch.before_verify)", "punch.before_verify"},
    {"Time Entry After Record (time_entry.after_record)", "time_entry.after_record"},
    {"Geolocation Validate (geolocation.validate)", "geolocation.validate"},
    {"Absence After Approve (absence.after_approve)", "absence.after_approve"},
    {"Periodic Adjustment (adjustment.periodic)", "adjustment.periodic"},
    {"Approval After Approve (approval.after_approve)", "approval.after_approve"},
    {"Delegation Updated (delegation.updated)", "delegation.updated"},
    {"Shift Differential (shift.differential)", "shift.differential"},
    {"Break Compliance (break.compliance)", "break.compliance"},
    {"Schedule Synced (schedule.synced)", "schedule.synced"},
    {"Payroll Code Sync (payroll.code_sync)", "payroll.code_sync"},
    {"Security Token Revoked (security.token_revoked)", "security.token_revoked"}
  ]

  @default_sample_lua """
  -- Example: inspect `context` and return `{ ok = true }` or `{ ok = false, error = "..." }`
  tc.log("Running hook at " .. tc.now_utc())
  return { ok = true }
  """

  @default_sample_json """
  {
    "clocking": {
      "source": "web",
      "has_geo_location": true
    }
  }
  """

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if admin?(current_user) do
      {:ok,
       socket
       |> assign(
         page_title: "Lua Plugin Registry & Sandbox",
         scripts: fetch_scripts(current_user),
         hook_options: @hook_options,
         form: build_create_form(current_user),
         sandbox_code: @default_sample_lua,
         sandbox_json: @default_sample_json,
         sandbox_output: nil
       )
       |> allow_upload(:lua_file,
         accept: ~w(.lua),
         max_entries: 1,
         max_file_size: 65_536,
         auto_upload: true,
         progress: &handle_progress/3
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied: Administrator privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  defp handle_progress(:lua_file, entry, socket) do
    if entry.done? do
      uploaded_source =
        consume_uploaded_entries(socket, :lua_file, fn %{path: path}, _entry ->
          {:ok, File.read!(path)}
        end)
        |> List.first()

      if is_binary(uploaded_source) do
        current_params = socket.assigns.form.params || %{}
        base_name = Path.rootname(entry.client_name) |> String.downcase() |> String.replace(~r/[^a-z0-9_\-]/, "_")

        merged =
          current_params
          |> Map.put("source_code", uploaded_source)
          |> Map.put_new("name", base_name)

        form =
          socket.assigns.form
          |> AshPhoenix.Form.validate(merged)
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Loaded #{entry.client_name} into editor.")
         |> assign(form: form, sandbox_code: uploaded_source)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, form: form, sandbox_code: Map.get(params, "source_code", socket.assigns.sandbox_code))}
  end

  @impl true
  def handle_event("save_script", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _script} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lua plugin registered and active.")
         |> assign(
           scripts: fetch_scripts(current_user),
           form: build_create_form(current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_event("toggle_script", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, script} <- Ash.get(Timeclock.Plugins.Script, id, actor: current_user),
         {:ok, _updated} <-
           Ash.update(script, :toggle_active, %{is_active: !script.is_active}, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Plugin status updated.")
       |> assign(scripts: fetch_scripts(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to toggle plugin.")}
    end
  end

  @impl true
  def handle_event("delete_script", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    with {:ok, script} <- Ash.get(Timeclock.Plugins.Script, id, actor: current_user),
         :ok <- Ash.destroy(script, actor: current_user) do
      {:noreply,
       socket
       |> put_flash(:info, "Plugin deleted from registry.")
       |> assign(scripts: fetch_scripts(current_user))}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to delete plugin.")}
    end
  end

  @impl true
  def handle_event("load_into_sandbox", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Ash.get(Timeclock.Plugins.Script, id, actor: current_user) do
      {:ok, script} ->
        {:noreply, assign(socket, sandbox_code: script.source_code, sandbox_output: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Plugin not found.")}
    end
  end

  @impl true
  def handle_event("run_sandbox", %{"source_code" => code, "sample_json" => json_str}, socket) do
    output =
      case Jason.decode(json_str) do
        {:ok, payload} when is_map(payload) ->
          case Timeclock.Plugins.LuaRunner.run_script(code, payload, script_name: "sandbox_test") do
            {:ok, data} -> {:ok, Jason.encode!(data, pretty: true)}
            {:error, reason} -> {:error, inspect(reason)}
          end

        _ ->
          {:error, "Sample Context JSON must be a valid JSON object."}
      end

    {:noreply, assign(socket, sandbox_code: code, sandbox_json: json_str, sandbox_output: output)}
  end

  defp fetch_scripts(actor) do
    Timeclock.Plugins.Script
    |> Ash.Query.sort(hook_event: :asc, priority: :asc)
    |> Ash.read!(actor: actor)
  end

  defp build_create_form(actor) do
    Timeclock.Plugins.Script
    |> AshPhoenix.Form.for_create(:create,
      params: %{"source_code" => @default_sample_lua, "priority" => 100, "is_active" => true},
      actor: actor
    )
    |> to_form()
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-7xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Lua Plugin Registry & Sandbox</h1>
        <p class="text-sm text-gray-500 mt-1">
          Upload or write sandboxed `.lua` hook scripts. If no plugins are active for an event, Reactors pass through automatically.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Upload / Register Form -->
        <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm h-fit space-y-4">
          <h2 class="text-lg font-bold text-gray-900">Register Lua Plugin</h2>

          <form phx-change="validate" class="p-3 border-2 border-dashed border-indigo-200 rounded-lg bg-indigo-50/30 text-center">
            <label class="cursor-pointer block text-xs font-semibold text-indigo-700">
              Upload `.lua` file (max 64 KB)
              <.live_file_input upload={@uploads.lua_file} class="mt-2 block w-full text-xs text-gray-500" />
            </label>
          </form>

          <.form for={@form} phx-change="validate" phx-submit="save_script" class="space-y-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Plugin ID</label>
              <.input
                field={@form[:name]}
                type="text"
                placeholder="e.g. enforce_gps_web_punch"
                class="w-full text-xs font-mono"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Reactor Hook</label>
              <.input
                field={@form[:hook_event]}
                type="select"
                options={@hook_options}
                prompt="Select Reactor hook event..."
                class="w-full text-xs"
              />
            </div>

            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Priority</label>
                <.input field={@form[:priority]} type="number" min="1" max="10000" class="w-full text-xs" />
              </div>
              <div class="flex items-end pb-2">
                <label class="inline-flex items-center gap-2 text-xs font-semibold text-gray-700">
                  <.input field={@form[:is_active]} type="checkbox" class="rounded text-indigo-600" />
                  Active Immediately
                </label>
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Description</label>
              <.input
                field={@form[:description]}
                type="text"
                placeholder="What business rule does this script enforce?"
                class="w-full text-xs"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase mb-1">Lua Source</label>
              <.input
                field={@form[:source_code]}
                type="textarea"
                rows="8"
                class="w-full font-mono text-xs bg-slate-900 text-emerald-300"
              />
Validate & Register Plugin

</.form>
Registered Hook Plugins

Plugin	Hook Event	Priority	Status	Actions
	{script.hook_event}	{script.priority}		
No Lua plugins registered yet. All Reactor hooks pass through cleanly by default.

Sandbox Dry-Run Tester


Lua Code
<%= @sandbox_code %>

Sample context JSON
<%= @sandbox_json %>

Execute Dry-Run (100ms Limit)


<%= case @sandbox_output do %>
<% {:ok, json_out} -> %>
PASS (Returned Data):
{json_out}
<% {:error, err} -> %>
REJECTED / ERROR:
{err}
<% end %>





"""
end
end