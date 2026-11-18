defmodule Timeclock.Accounts.Token do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication.TokenResource, AshOban]

  attributes do
    attribute :jti, :string do
      primary_key? true
      public? false
      allow_nil? false
      sensitive? true
    end

    attribute :subject, :string do
      allow_nil? false
      public? false
    end

    attribute :expires_at, :utc_datetime do
      allow_nil? false
      public? false
    end

    attribute :purpose, :string do
      allow_nil? false
      public? false
    end

    attribute :extra_data, :map do
      public? false
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  postgres do
    table "tokens"
    repo Timeclock.Repo

    custom_indexes do
      index [:subject, :purpose]
      index [:expires_at]
    end
  end

  oban do
    triggers do
      # Purges expired tokens every hour at minute 10
      trigger :expunge_expired_tokens do
        action :expunge_expired
        where expr(expires_at < now())
        scheduler_cron "10 * * * *"
        worker_read_action :expired
      end
    end
  end

  actions do
    defaults [:read]

    read :expired do
      description "Look up all expired tokens."
      filter expr(expires_at < now())
    end

    read :get_token do
      description "Look up a token by JTI or token, and an optional purpose."
      get? true
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true
      argument :purpose, :string, sensitive?: false

      prepare AshAuthentication.TokenResource.GetTokenPreparation
    end

    action :revoked?, :boolean do
      description "Returns true if a revocation token is found for the provided token."
      argument :token, :string, sensitive?: true
      argument :jti, :string, sensitive?: true

      run AshAuthentication.TokenResource.IsRevoked
    end

    create :revoke_token do
      description "Revoke a token. Creates a revocation token corresponding to the provided token."
      accept [:extra_data]
      argument :token, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeTokenChange
      change run_reactor(Timeclock.Accounts.Reactors.BroadcastTokenRevocation)
    end

    create :revoke_jti do
      description "Revoke a token by JTI. Creates a revocation token corresponding to the provided JTI."
      accept [:extra_data]
      argument :subject, :string, allow_nil?: false, sensitive?: true
      argument :jti, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeJtiChange
      change run_reactor(Timeclock.Accounts.Reactors.BroadcastTokenRevocation)
    end

    create :store_token do
      description "Stores a token used for the provided purpose."
      accept [:extra_data, :purpose]
      argument :token, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.StoreTokenChange
    end

    update :revoke_all_stored_for_subject do
      description "Revokes all stored tokens for a specific subject."
      accept [:extra_data]
      require_atomic? false
      argument :subject, :string, allow_nil?: false, sensitive?: true

      change AshAuthentication.TokenResource.RevokeAllStoredForSubjectChange
      change run_reactor(Timeclock.Accounts.Reactors.BroadcastTokenRevocation)
    end

    destroy :expunge_expired do
      description "Deletes expired tokens."
      require_atomic? false
      change filter expr(expires_at < now())
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      description "AshAuthentication can interact with the token resource"
      authorize_if always()
    end

    bypass AshOban.Checks.AshObanInteraction do
      description "AshOban can expunge expired tokens in the background"
      authorize_if action([:expired, :expunge_expired])
    end

    policy always() do
      description "No one aside from AshAuthentication and internal Oban cleanup can access tokens"
      forbid_if always()
    end
  end
end
