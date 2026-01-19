defmodule Timeclock.Accounts.User do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshCommanded.Commanded.Dsl]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Timeclock.Accounts.Token
      signing_secret Timeclock.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Timeclock.Accounts.User.Senders.SendMagicLinkEmail
      end
    end
  end

  postgres do
    table "users"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read]

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token"
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      change {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenChange,
              strategy_name: :remember_me}

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end

    create :register do
      accept [:user_name, :email]
      change set_attribute(:status, :pending)
    end

    update :confirm_email do
      accept []
      change set_attribute(:status, :active)
    end
  end

  policies do
    policy action(:change_password) do
      description "Users can change their own password"
      authorize_if expr(id == ^actor(:id))
    end

    #    field_policy_bypass :* do
    #      description "Users can access all fields for password change"
    #      authorize_if Timeclock.Checks.PasswordChangeInteraction
    #    end

    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :user_name, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :status, :ci_string do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  relationships do
    has_one :account, Timeclock.Accounts.Account do
      public? true
    end

    has_many :clockings, Timeclock.Clocking.Clocking
    has_many :audit_logs, Timeclock.Audit.Log
    has_many :request_logs, Timeclock.Approvals.RequestLog
    has_many :employees, Timeclock.Accounts.Employee
    has_many :managers, Timeclock.Accounts.Manager
    has_many :roles, Timeclock.Accounts.Role
  end

  validations do
    validate present([:delegated_user_id, :user_id]), on: [:create, :update]
    validate string_length(:user_name, min: 1, max: 255), on: [:create, :update]
  end

  #  commanded do
  #    commands do
  #      command :register_user do
  #        fields([:id, :user_name, :email])
  #        identity_field :id
  #        action :register
  #      end
  #
  #      command :confirm_email do
  #        fields([:id])
  #        identity_field :id
  #        action :confirm_email
  #      end
  #    end
  #
  #    events do
  #      event :user_registered do
  #        fields([:id, :user_name, :email])
  #      end
  #
  #      event :email_confirmed do
  #        fields([:id])
  #      end
  #    end
  #
  #    projections do
  #      projection :user_registered do
  #        action :create
  #
  #        changes(%{
  #          status: :pending
  #        })
  #      end
  #
  #      projection :email_confirmed do
  #        action :update_by_id
  #
  #        changes(%{
  #          status: :active
  #        })
  #      end
  #    end
  #
  #    event_handlers do
  #      handler :notification_handler do
  #        events([:user_registered])
  #
  #        action fn event, _metadata ->
  #          #  ECommerce.Notifications.send_welcome_email(event.email)
  #          :ok
  #        end
  #      end
  #
  #      handler :analytics_tracker do
  #        events([:user_registered, :email_confirmed])
  #
  #        action fn event, _metadata ->
  #          # ECommerce.Analytics.track(event)
  #          :ok
  #        end
  #      end
  #    end
  #  end
end
