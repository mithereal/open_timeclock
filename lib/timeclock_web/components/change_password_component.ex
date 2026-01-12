# lib/my_app_web/components/change_password_component.ex
defmodule TimeclockWeb.ChangePasswordComponent do
  @moduledoc """
  LiveComponent for changing the current user's password.
  """
  use TimeclockWeb, :live_component
  # alias Timeclock.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="user-password-change-form"
        phx-target={@myself}
        phx-submit="save"
      >
        <.input field={@form[:current_password]} type="password" label="Current Password" />
        <.input field={@form[:password]} type="password" label="New Password" />
        <.input field={@form[:password_confirmation]} type="password" label="Confirm New Password" />
        <:actions>
          <.button phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_form()}
  end

  defp assign_form(%{assigns: %{current_user: user}} = socket) do
    form =
      AshPhoenix.Form.for_update(user, :change_password,
        as: "user",
        prepare_source: fn changeset ->
          %{
            changeset
            | data:
                Ash.load!(changeset.data, :hashed_password,
                  context: %{private: %{password_change?: true}}
                )
          }
        end,
        actor: user
      )

    assign(socket, form: to_form(form))
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, %{assigns: assigns} = socket) do
    case AshPhoenix.Form.submit(assigns.form, params: user_params) do
      {:ok, _user} ->
        assigns.on_saved.()
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end
end
