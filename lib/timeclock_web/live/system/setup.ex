defmodule TimeclockWeb.UserLive.Setup do
  use TimeclockWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pt-5 dark:bg-black mx-auto">
      <div class="bg-white dark:bg-black w-5/6 md:w-3/4 lg:w-2/3 xl:w-[500px] 2xl:w-[550px] mt-4 mx-auto px-16 py-8 rounded-lg shadow-2xl">
        <div :if={@step == 1} class="text-center">
          <.header>Welcome</.header>
          <div class="text-black text-sm">Your almost there just a few quick questions</div>
          <.form
            :let={f}
            for={@account_form}
            id="account_form"
            action={~p"/setup"}
            phx-submit="submit_account"
          >
            <.button class="mt-4 btn btn-primary w-full">
              Next
            </.button>
          </.form>
        </div>
      </div>
      <div class="bg-transparent dark:bg-black w-5/6 md:w-3/4 lg:w-2/3 xl:w-[500px] 2xl:w-[950px] mt-4 mx-auto px-8 py-8 rounded-lg ">
        <div :if={@step == 2} class="text-center">
          <.header>Select working time preset and adjust settings</.header>
          <div class="text-black text-sm"></div>
          <.form
            :let={f}
            for={@settings_form}
            id="settings_form"
            action={~p"/setup"}
            phx-submit="submit_settings"
          >
            <.field_input name="Daily Plan" value="" type="text" label="Daily Plan" required />
            <.field_input name="Paid time rule" value="" type="text" label="Paid time rule" required />
            <.field_input
              name="Paid time limit"
              value=""
              type="text"
              label="Paid time limit"
              required
            />
            <.field_input
              name="Enable Lunch break"
              value=""
              type="text"
              label="Enable Lunch break "
              required
            />
            <.field_input
              name="Lunch break duration"
              value=""
              type="text"
              label="Lunch break duration"
              required
            />
            <.field_input
              name="Required Presence"
              value=""
              type="text"
              label="Required Presence"
              required
            />
            <.field_input
              name="Required Presence Rule"
              value=""
              type="text"
              label="Required Presence Rule"
              required
            />

            <.button class="btn btn-primary w-full">
              Finish
            </.button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:category, :dashboard)
      |> assign(:account_form, to_form(%{"full_name" => nil}, as: "account_form"))
      |> assign(:settings_form, to_form(%{"full_name" => nil}, as: "account_form"))
      |> assign(:step, 1)
      |> assign(:trigger_submit, false)
      |> assign(:page_title, "Setup your Account")

    {:ok, socket}
  end

  def handle_event(
        "submit_company",
        company,
        socket
      ) do
    socket = socket |> assign(:company, company) |> assign(:step, 3)
    {:noreply, socket}
  end

  def handle_event("submit_account", %{"account_type" => type, "full_name" => full_name}, socket) do
    socket = socket |> assign(:type, type) |> assign(:full_name, full_name) |> assign(:step, 2)
    {:noreply, socket}
  end

  def handle_event("submit", location, socket) do
    socket = socket |> assign(:location, location)

    write(socket.assigns)

    {:noreply,
     socket
     |> push_navigate(to: ~p"/home")}
  end

  defp write(assigns) do
    :ok
  end
end
