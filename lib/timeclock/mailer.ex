defmodule Timeclock.Mailer do
  use Swoosh.Mailer, otp_app: :timeclock

  import Swoosh.Email, only: [html_body: 2, text_body: 2]

  # Inline CSS so it works in all browsers
  def premail(email) do
    html = Premailex.to_inline_css(email.html_body)
    text = Premailex.to_text(email.html_body)

    email
    |> html_body(html)
    |> text_body(text)
  end

  def premailx() do
    quote do
      import Swoosh.Email

      import Timeclock.Mailer, only: [premail: 1, deliver: 1]

      use Phoenix.Swoosh, view: TimeclockWeb.Emails, layout: {TimeclockWeb.Emails, :layout}

      use Phoenix.VerifiedRoutes,
        endpoint: TimeclockWeb.Endpoint,
        router: TimeclockWeb.Router

      @sender Application.compile_env(:Timeclock, :sender)
      @domain Application.compile_env(:Timeclock, :domain)
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
