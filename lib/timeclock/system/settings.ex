defmodule Timeclock.System.Settings do
  @moduledoc """
  Singleton system configuration for outbound email and provider credentials.
  Sensitive credentials are encrypted at rest and accessible only to admins.
  """
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  alias Timeclock.Types.EncryptedBinary

  attributes do
    uuid_primary_key :id

    # Enforces a single configuration row in Postgres
    attribute :singleton_key, :string do
      public? false
      allow_nil? false
      default "default"
    end

    # Email sender
    attribute :email_from_name, :string do
      public? true
      allow_nil? false
      default "Timeclock"
      constraints min_length: 1, max_length: 100, trim?: true
    end

    attribute :email_from_address, :string do
      public? true
      allow_nil? false
      default "noreply@example.com"
      constraints min_length: 5,
                  max_length: 254,
                  trim?: true,
                  match: ~r/^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/
    end

    # Email provider
    attribute :email_provider, :atom do
      public? true
      allow_nil? false
      default :smtp
      constraints one_of: [:smtp, :sendgrid, :mailgun, :postmark, :brevo, :amazon_ses]
    end

    attribute :email_api_key, EncryptedBinary do
      public? false
      sensitive? true
    end

    attribute :email_api_secret, EncryptedBinary do
      public? false
      sensitive? true
    end

    attribute :email_api_domain, :string do
      public? true
      constraints max_length: 255, trim?: true
    end

    attribute :email_api_region, :string do
      public? true
      default "us-east-1"
      constraints min_length: 2, max_length: 50, trim?: true
    end

    # SMTP configuration
    attribute :smtp_host, :string do
      public? true
      constraints max_length: 255, trim?: true
    end

    attribute :smtp_port, :integer do
      public? true
      default 587
      constraints min: 1, max: 65_535
    end

    attribute :smtp_username, :string do
      public? true
      constraints max_length: 255, trim?: true
    end

    attribute :smtp_password, EncryptedBinary do
      public? false
      sensitive? true
    end

    attribute :smtp_tls, :atom do
      public? true
      default :if_available
      constraints one_of: [:if_available, :always, :never]
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_singleton, [:singleton_key]
  end

  postgres do
    table "settings"
    repo Timeclock.Repo
  end

  validations do
    validate present(:smtp_host),
      where: attribute_equals(:email_provider, :smtp),
      on: [:update],
      message: "is required when email provider is SMTP"

    validate present(:email_api_key),
      where: negate(attribute_equals(:email_provider, :smtp)),
      on: [:update],
      message: "is required for API-based email providers"
  end

  actions do
    defaults [:read]

    read :get do
      get? true
      filter expr(singleton_key == "default")
    end

    # Safe bootstrap action: only succeeds if no Settings row exists yet
    create :init do
      accept []

      validate fn changeset, _context ->
        case Ash.count(Timeclock.System.Settings, authorize?: false) do
          {:ok, 0} -> :ok
          _ -> {:error, field: :singleton_key, message: "system settings are already initialized"}
        end
      end
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :email_from_name,
        :email_from_address,
        :email_provider,
        :email_api_key,
        :email_api_secret,
        :email_api_domain,
        :email_api_region,
        :smtp_host,
        :smtp_port,
        :smtp_username,
        :smtp_password,
        :smtp_tls
      ]
    end
  end

  policies do
    # Allow one-time bootstrap initialization when unauthenticated
    policy action(:init) do
      authorize_if always()
    end

    # Require authenticated admin for all reads and updates of system credentials
    policy action_type([:read, :update]) do
      forbid_unless actor_present()
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
