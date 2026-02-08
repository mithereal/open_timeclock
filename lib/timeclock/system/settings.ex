defmodule Timeclock.System.Settings do
  @moduledoc false
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  alias Timeclock.Types.EncryptedBinary

  postgres do
    table "settings"
    repo Timeclock.Repo
  end

  actions do
    default_accept :*

    defaults [:read, :update]

    create :init do
      accept []
    end

    read :get do
      get? true
    end
  end

  policies do
    # Allow read of settings for everyone (used across site)
    policy action_type(:read) do
      authorize_if always()
    end

    # Allow init (bootstrap) without auth
    policy action(:init) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    # Email sender
    attribute :email_from_name, :string do
      public? true
      allow_nil? false
      default "Timeclock"
    end

    attribute :email_from_address, :string do
      public? true
      allow_nil? false
      default "noreply@example.com"
    end

    # Email provider
    attribute :email_provider, :atom do
      public? true
      allow_nil? false
      default :smtp
      constraints one_of: [:smtp, :sendgrid, :mailgun, :postmark, :brevo, :amazon_ses]
    end

    attribute :email_api_key, EncryptedBinary do
      public? true
      sensitive? true
    end

    attribute :email_api_secret, EncryptedBinary do
      public? true
      sensitive? true
    end

    attribute :email_api_domain, :string do
      public? true
    end

    attribute :email_api_region, :string do
      public? true
      default "us-east-1"
    end

    # SMTP configuration
    attribute :smtp_host, :string do
      public? true
    end

    attribute :smtp_port, :integer do
      public? true
      default 587
    end

    attribute :smtp_username, :string do
      public? true
    end

    attribute :smtp_password, :string do
      public? true
      sensitive? true
    end

    attribute :smtp_tls, :atom do
      public? true
      default :if_available
      constraints one_of: [:if_available, :always, :never]
    end
  end
end
