defmodule TimeclockWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use TimeclockWeb, :controller
      use TimeclockWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: true

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: TimeclockWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: TimeclockWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import TimeclockWeb.CoreComponents

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias TimeclockWeb.Layouts

      import TimeclockWeb.ScheduleGanttComponent
      import TimeclockWeb.Components.Alert
      import TimeclockWeb.Components.Avatar
      import TimeclockWeb.Components.Badge
      import TimeclockWeb.Components.Breadcrumb
      import TimeclockWeb.Components.Dropdown
      import TimeclockWeb.Components.EmailField
      import TimeclockWeb.Components.TelField
      import TimeclockWeb.Components.Button
      import TimeclockWeb.Components.Combobox
      import TimeclockWeb.Components.Markdown
      import TimeclockWeb.Components.Modal
      import TimeclockWeb.Components.Card
      import TimeclockWeb.Components.Gallery
      import TimeclockWeb.Components.FormWrapper
      import TimeclockWeb.Components.Divider
      import TimeclockWeb.Components.Progress
      import TimeclockWeb.Components.CheckboxField
      import TimeclockWeb.Components.TextareaField
      # import TimeclockWeb.Components.Icon
      import TimeclockWeb.Components.Image
      import TimeclockWeb.Components.TextField
      import TimeclockWeb.Components.InputField
      import TimeclockWeb.Components.NativeSelect
      import TimeclockWeb.Components.Navbar
      import TimeclockWeb.Components.PasswordField
      import TimeclockWeb.Components.ScrollArea
      import TimeclockWeb.Components.Sidebar
      import TimeclockWeb.Components.ToggleField
      import TimeclockWeb.Components.Tabs
      import TimeclockWeb.Components.Stepper
      import TimeclockWeb.Components.Timeline

      def get_user_email(scope) do
        case scope do
          nil -> ""
          scope -> scope.user.email
        end
      end

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: TimeclockWeb.Endpoint,
        router: TimeclockWeb.Router,
        statics: TimeclockWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
