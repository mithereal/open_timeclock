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
    end
  end

  def apply_settings(settings) do
    case provider_config(settings) do
      nil -> :ok
      config -> apply_config(config, settings)
    end
  end

  defp sender_config(s) do
    if present?(s.email_from_address && s.email_from_name),
      do: [email_from_address: s.email_from_address, email_from_name: s.email_from_name]
  end

  defp provider_config(%{email_provider: :sendgrid} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.SendGrid, api_key: s.email_api_key]
  end

  defp provider_config(%{email_provider: :postmark} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.Postmark, api_key: s.email_api_key]
  end

  defp provider_config(%{email_provider: :brevo} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.Brevo, api_key: s.email_api_key]
  end

  defp provider_config(%{email_provider: :mailgun} = s) do
    if present?(s.email_api_key),
      do: [adapter: Swoosh.Adapters.Mailgun, api_key: s.email_api_key, domain: s.email_api_domain]
  end

  defp provider_config(%{email_provider: :amazon_ses} = s) do
    if present?(s.email_api_key) and present?(s.email_api_secret) do
      [
        adapter: Swoosh.Adapters.AmazonSES,
        access_key: s.email_api_key,
        secret: s.email_api_secret,
        region: s.email_api_region || "us-east-1"
      ]
    end
  end

  defp provider_config(%{email_provider: :smtp} = s) do
    if present?(s.smtp_host) do
      has_credentials? = present?(s.smtp_username) and present?(s.smtp_password)

      [
        adapter: Swoosh.Adapters.SMTP,
        relay: s.smtp_host,
        port: s.smtp_port || 587,
        username: s.smtp_username || "",
        password: s.smtp_password || "",
        tls: s.smtp_tls || :if_available,
        auth: if(has_credentials?, do: :always, else: :never)
      ]
    end
  end

  defp provider_config(_), do: nil

  defp apply_config(config, params) do
    config = sender_config(params) ++ config
    Application.put_env(:timeclock, __MODULE__, config)
    Application.put_env(:swoosh, :api_client, Swoosh.ApiClient.Finch)
    Application.put_env(:swoosh, :finch_name, Timeclock.Finch)
    :ok
  end

  defp present?(value), do: value not in [nil, ""]

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
