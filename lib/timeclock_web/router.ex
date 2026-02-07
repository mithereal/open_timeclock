defmodule TimeclockWeb.Router do
  use TimeclockWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  alias TimeclockWeb.LiveUserAuth
  alias TimeclockWeb.AuthOverrides
  alias AshAuthentication.Phoenix.Overrides.Default

  @csp Enum.join(
         [
           "default-src 'self'",
           "base-uri 'self'",
           "frame-ancestors 'self'",
           "img-src 'self' data: blob:",
           "style-src 'self' 'unsafe-inline'",
           "font-src 'self' data:",
           "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
           "connect-src 'self' ws: wss:"
         ],
         "; "
       )

  def put_session_timezone(conn, _opts) do
    timezone = conn.cookies["timezone"]
    put_session(conn, "timezone", timezone)
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TimeclockWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp
    plug :load_from_session
    plug :put_session_timezone
  end

  pipeline :user do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TimeclockWeb.Layouts, :user}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp
    plug :load_from_session
    plug :put_session_timezone
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", TimeclockWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {TimeclockWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {TimeclockWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {TimeclockWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", TimeclockWeb do
    pipe_through :browser

    get "/", PageController, :landing
    auth_routes AuthController, Timeclock.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{LiveUserAuth, :live_no_user}],
                  overrides: [
                    AuthOverrides,
                    Default,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  AuthOverrides,
                  Default,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Timeclock.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [TimeclockWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Timeclock.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", TimeclockWeb do
  #   pipe_through :api
  # end

  scope "/admin", TimeclockWeb do
    pipe_through :user

    ash_authentication_live_session :authentication_required,
      on_mount: [{LiveUserAuth, :live_user_required}, {AshScope, :current_scope}] do
      live "/online/:name", OnlineLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:timeclock, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TimeclockWeb.Telemetry

      forward "/mailbox", Plug.Swoosh.MailboxPreview,
        csp_nonce_assign_key: %{script: :script_csp_nonce, style: :style_csp_nonce}
    end
  end

  if Application.compile_env(:timeclock, :dev_routes) do
    import AshAdmin.Router

    scope "/home" do
      pipe_through [:browser, :user]

      ash_authentication_live_session :authenticated_user,
        on_mount: {LiveUserAuth, :live_user_required} do
        live "/", TimeclockWeb.Dashboard.IndexLive, :index
        live "/setup", TimeclockWeb.System.SetupLive, :index
      end

      live "/online/:name", TimeclockWeb.OnlineLive, :index
      # ash_admin "/"
    end
  end

  defp put_csp(conn, _opts), do: Plug.Conn.put_resp_header(conn, "content-security-policy", @csp)
end
