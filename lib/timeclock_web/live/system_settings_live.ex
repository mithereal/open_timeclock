defmodule TimeclockWeb.SystemSettingsLive do
  use TimeclockWeb, :live_view

  @provider_options [
    {"SMTP Server Delivery", "smtp"},
    {"SendGrid API", "sendgrid"},
    {"Mailgun Engine", "mailgun"},
    {"Postmark Client", "postmark"},
    {"Brevo Suite", "brevo"},
    {"Amazon SES", "amazon_ses"}
  ]

  @tls_options [
    {"Upgrade if Available", "if_available"},
    {"Enforce TLS Encryption", "always"},
    {"Plain Communication", "never"}
  ]

  @secret_fields ~w(email_api_key email_api_secret smtp_password)

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if admin?(current_user) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Timeclock.PubSub, "system:settings")
      end

      settings = fetch_or_init_settings(current_user)

      {:ok,
       assign(socket,
         page_title: "Global Communication Parameters",
         settings: settings,
         form: build_update_form(settings, current_user),
         provider_options: @provider_options,
         tls_options: @tls_options
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Access denied: Administrator privileges required.")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    sanitized_params = strip_blank_secrets(params)

    form =
      socket.assigns.form
      |> AshPhoenix.Form.validate(sanitized_params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    current_user = socket.assigns.current_user
    sanitized_params = strip_blank_secrets(params)

    case AshPhoenix.Form.submit(socket.assigns.form, params: sanitized_params) do
      {:ok, fresh} ->
        {:noreply,
         socket
         |> put_flash(:info, "System communication settings saved.")
         |> assign(
           settings: fresh,
           form: build_update_form(fresh, current_user)
         )}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  @impl true
  def handle_info({:settings_updated, _payload}, socket) do
    current_user = socket.assigns.current_user
    fresh = fetch_or_init_settings(current_user)

    {:noreply,
     assign(socket,
       settings: fresh,
       form: build_update_form(fresh, current_user)
     )}
  end

  defp fetch_or_init_settings(current_user) do
    case Ash.read!(Timeclock.System.Settings, actor: current_user) do
      [] ->
        Timeclock.System.Settings
        |> Ash.Changeset.for_create(:init, %{}, actor: current_user)
        |> Ash.create!()

      [record | _] ->
        record
    end
  end

  defp build_update_form(settings, current_user) do
    settings
    |> AshPhoenix.Form.for_update(:update, actor: current_user)
    |> to_form()
  end

  # Prevents blank password fields from wiping out existing encrypted secrets on save
  defp strip_blank_secrets(params) do
    Enum.reduce(@secret_fields, params, fn key, acc ->
      case Map.get(acc, key) do
        "" -> Map.delete(acc, key)
        nil -> Map.delete(acc, key)
        _ -> acc
      end
    end)
  end

  defp admin?(%{role: :admin}), do: true
  defp admin?(_), do: false

  defp smtp_selected?(form) do
    Phoenix.HTML.Form.input_value(form, :email_provider) in [:smtp, "smtp"]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-4xl mx-auto space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Global Communication Parameters</h1>
        <p class="text-sm text-gray-500 mt-1">
          Configure outbound email delivery providers, encrypted API keys, and SMTP relay settings.
        </p>
      </div>

      <div class="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-5">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Sender Display Name
              </label>
              <.input
                field={@form[:email_from_name]}
                type="text"
                placeholder="Timeclock"
                class="w-full text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Sender Email Address
              </label>
              <.input
                field={@form[:email_from_address]}
                type="email"
                placeholder="noreply@yourdomain.com"
                class="w-full text-sm"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 border-t pt-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Delivery Provider
              </label>
              <.input
                field={@form[:email_provider]}
                type="select"
                options={@provider_options}
                class="w-full text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                API Domain
              </label>
              <.input
                field={@form[:email_api_domain]}
                type="text"
                placeholder="://yourdomain.com"
                class="w-full text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                API Region
              </label>
              <.input
                field={@form[:email_api_region]}
                type="text"
                placeholder="us-east-1"
                class="w-full text-sm"
              />
            </div>
          </div>

          <div :if={!smtp_selected?(@form)} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Provider API Key
              </label>
              <.input
                field={@form[:email_api_key]}
                type="password"
                autocomplete="new-password"
                placeholder="Leave blank to keep existing key"
                class="w-full text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                Provider API Secret
              </label>
              <.input
                field={@form[:email_api_secret]}
                type="password"
                autocomplete="new-password"
                placeholder="Leave blank to keep existing secret"
                class="w-full text-sm"
              />
            </div>
          </div>

          <div
            :if={smtp_selected?(@form)}
            class="space-y-4 pt-4 border-t bg-gray-50 p-4 rounded-xl"
          >
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div class="sm:col-span-2">
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  SMTP Host
                </label>
                <.input
                  field={@form[:smtp_host]}
                  type="text"
                  placeholder="smtp.relay.io"
                  class="w-full text-sm bg-white"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  SMTP Port
                </label>
                <.input
                  field={@form[:smtp_port]}
                  type="number"
                  min="1"
                  max="65535"
                  class="w-full text-sm bg-white"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  SMTP Username
                </label>
                <.input
                  field={@form[:smtp_username]}
                  type="text"
                  autocomplete="off"
                  class="w-full text-sm bg-white"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  SMTP Password
                </label>
                <.input
                  field={@form[:smtp_password]}
                  type="password"
                  autocomplete="new-password"
                  placeholder="Leave blank to keep existing"
                  class="w-full text-sm bg-white"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 uppercase tracking-wider mb-1">
                  TLS Mode
                </label>
                <.input
                  field={@form[:smtp_tls]}
                  type="select"
                  options={@tls_options}
                  class="w-full text-sm bg-white"
                />
              </div>
            </div>
          </div>

          <div class="flex justify-end pt-3 border-t">
            <button
              type="submit"
              class="bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-6 rounded shadow transition text-sm"
            >
              Save Communication Settings
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
end
end