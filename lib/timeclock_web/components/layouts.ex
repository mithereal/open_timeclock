defmodule TimeclockWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TimeclockWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8"></header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  #
  #  attr :current_scope, Timeclock.Scope, default: nil
  #
  #  def sidebar_nav(assigns) do
  #    ~H"""
  #    <div>
  #      <aside id="drawer-navigation" class="nav-drawer" aria-label={gettext("Sidebar")} tabindex="-1">
  #        <.sidebar minimize="false" hide_position="left" content_class="flex flex-col">
  #          <:item
  #            icon="hero-computer-desktop"
  #            icon_class="text-gray-500"
  #            label="Dashboard"
  #            label_class="text-lg text-gray-700"
  #            link="/home"
  #          />
  #          <:item
  #            icon="hero-user-group"
  #            icon_class="text-gray-500"
  #            label="Customers"
  #            label_class="text-lg text-gray-700"
  #            link="/home/customers"
  #          />
  #          <:item
  #            icon="hero-chat-bubble-left"
  #            icon_class="text-gray-500"
  #            label="Quotes"
  #            label_class="text-lg text-gray-700"
  #            link="/home/quotes"
  #          />
  #          <:item
  #            icon="hero-banknotes"
  #            icon_class="text-gray-500"
  #            label="Sales"
  #            label_class="text-lg text-gray-700"
  #            link="/home/sales"
  #          />
  #          <:item
  #            icon="hero-banknotes"
  #            icon_class="text-gray-500"
  #            label="Orders"
  #            label_class="text-lg text-gray-700"
  #            link="/home/orders"
  #          />
  #          <div class="grow"></div>
  #          <.user_menu_avatar class="flex-none" current_scope={@current_scope} />
  #          <div class="size-10 flex-none"></div>
  #        </.sidebar>
  #      </aside>
  #    </div>
  #    """
  #  end
  #
  #  def notification(assigns) do
  #    ~H"""
  #    <div class="relative mr-5" id="notification">
  #      <.dropdown
  #        id="notification_dropdown"
  #        relative="xs:relative"
  #        content_width="large"
  #        padding="extra_small"
  #      >
  #        <:trigger>
  #          <.avatar rounded="full">
  #            &#x1F514;
  #          </.avatar>
  #        </:trigger>
  #
  #        <:content>
  #          <div></div>
  #        </:content>
  #      </.dropdown>
  #    </div>
  #    """
  #  end
  #
  #  attr :current_scope, :map,
  #       default: Timeclock.Scope,
  #       doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  #
  #  def user_menu_avatar(assigns) do
  #    assigns =
  #      assign_new(assigns, :user_avatar, fn ->
  #        case assigns.current_scope.user.image do
  #          nil -> "/images/logo.png"
  #          "" -> "/images/logo.png"
  #          image -> image
  #        end
  #      end)
  #
  #    ~H"""
  #    <.dropdown
  #      clickable={false}
  #      relative="relative"
  #      id="user_menu_avatar"
  #      class="mx-auto"
  #      position="top"
  #    >
  #      <:trigger>
  #        <.button class="w-full" id="avatar_button">
  #          <div class="flex">
  #            <.avatar
  #              src={@user_avatar}
  #              size="large"
  #              border="extra_small"
  #              color="misc"
  #              rounded="full"
  #            /> <span class="mx-5">{@current_scope.user.username}</span>
  #          </div>
  #        </.button>
  #      </:trigger>
  #
  #      <:content>
  #        <ul>
  #          <li>
  #            <.avatar class="pl-8" color="base" id="settings">
  #              <:icon name="hero-cog-6-tooth" />
  #              <.link href={~p"/home/settings"}>Settings</.link>
  #            </.avatar>
  #          </li>
  #          <li>
  #            <.avatar class="pl-8" color="base" id="log_out">
  #              <:icon name="hero-arrow-left-end-on-rectangle" />
  #              <.link href={~p"/log_out"}>LogOut</.link>
  #            </.avatar>
  #          </li>
  #        </ul>
  #      </:content>
  #    </.dropdown>
  #    """
  #  end
  #
  #  attr :menu, :list, required: false, default: []
  #  attr :category, :string, required: false, default: ""
  #
  #  attr :current_scope, :map,
  #       default: Timeclock.Scope,
  #       doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  #
  #  def top_navbar(assigns) do
  #    ~H"""
  #    <.navbar id="nav-topbar" class="-mt-4 pl-4 bg-indigo-300" variant="shadow">
  #      <:end_content>
  #        <.notification />
  #      </:end_content>
  #      <:list>
  #        <div class="text-green-900 font-semibold">
  #          {Recase.to_title(to_string(@category))}
  #        </div>
  #        <%= for link <- @menu do %>
  #          <.link
  #            class="text-green-900  hover:text-orange-700 font-semibold"
  #            title="{link.name}"
  #            navigate="{link.url}"
  #          >
  #            {Recase.to_title(to_string(link.name))}
  #          </.link>
  #        <% end %>
  #      </:list>
  #    </.navbar>
  #    """
  #  end
  #
  #  attr :flash, :map, required: true, doc: "the map of flash messages"
  #  attr :page_title, :string, required: true, doc: "the page title"
  #
  #  attr :current_scope, :map,
  #       default: Timeclock.Scope,
  #       doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  #
  #  slot :inner_block, required: true
  #
  #  def user_app(assigns) do
  #    ~H"""
  #    <div>
  #      <div class="flex">
  #        <.sidebar_nav current_scope={@current_scope} hide_position="right" />
  #        <div class="w-full">
  #          <.top_navbar category={@page_title} menu={@menu} current_scope={@current_scope} />
  #          {render_slot(@inner_block)}
  #        </div>
  #      </div>
  #      <.flash_group flash={@flash} />
  #    </div>
  #    """
  #  end
  #
  #  def topbar_nav(assigns) do
  #    ~H"""
  #    <nav aria-label={gettext("Top")}>
  #      <div class="w-full mx-aut sm:px-10 px-4  bg-gray-800 py-2 text-gray-400 flex justify-between">
  #        <div>
  #          <a href={~p"/"} class="flex items-center space-x-3 rtl:space-x-reverse">
  #            <img src={~p"/images/logo.png"} class="h-8" alt="Logo" />
  #            <span class="font-display self-center text-2xl font-semibold whitespace-nowrap dark:text-white">
  #              INK
  #            </span>
  #          </a>
  #        </div>
  #        <div></div>
  #        <div class="flex gap-4 mr-4 ">
  #          <div>
  #            <.link
  #              navigate={~p"/register"}
  #              class="align-text-bottom font-semibold text-gray-300 hover:text-green-300 shojumaru-regular"
  #            >Start Free Trial</.link>
  #          </div>|
  #          <div>
  #            <.link
  #              class="font-semibold text-gray-300 shojumaru-regular hover:text-green-300"
  #              navigate={~p"/login"}
  #            >
  #              Login
  #            </.link>
  #          </div>
  #        </div>
  #      </div>
  #    </nav>
  #    """
  #  end
  #
  #  attr :mobile_title, :string, required: false, default: "Timeclock"
  #
  #  def mobile_nav(assigns) do
  #    ~H"""
  #    <header class="mobile-header">
  #      <nav class="mobile-nav" aria-label={gettext("Mobile")}>
  #        <.icon_button
  #          name="icon--menu-hamburger"
  #          border={false}
  #          phx-click={open_drawer()}
  #          class="nav-button"
  #          description={gettext("Open navigation drawer")}
  #        />
  #        <h1>{@mobile_title}</h1>
  #      </nav>
  #    </header>
  #    """
  #  end

  defp open_drawer, do: JS.set_attribute({"data-open", "true"}, to: "#drawer-navigation")
  defp close_drawer, do: JS.remove_attribute("data-open", to: "#drawer-navigation")
end
