defmodule Timeclock.Accounts.User do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshArchival.Resource]

  alias AshAuthentication.Strategy.Password.HashPasswordChange
  alias AshAuthentication.Strategy.Password.PasswordConfirmationValidation

  authentication do
    add_ons do
      confirmation :confirm_new_user do
        monitor_fields [:email]
        require_interaction? true
        confirm_on_create? true
        confirm_on_update? false
        auto_confirm_actions [:sign_in_with_magic_link, :reset_password_with_password]
        sender Timeclock.Accounts.User.Senders.SendNewUserConfirmationEmail
      end

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

      password :password do
        identity_field :email

        resettable do
          sender Timeclock.Accounts.User.Senders.SendPasswordResetEmail
        end

        # require_confirmed_with(:confirmed_at)
      end
    end
  end

  resource do
    base_filter expr(is_nil(archived_at))
  end

  postgres do
    table "users"
    repo Timeclock.Repo
    base_filter_sql "(archived_at IS NULL)"
  end

  archive do
    exclude_read_actions(:archived)
    archive_related([:account])

    # Recommended: bypass authorization for related records
    archive_related_authorize?(false)
  end

  actions do
    defaults [:read]

    read :list do
      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    #          read :list_admins do
    #      filter expr(:admin not_in(roles))
    #          end

    read :archived do
      filter expr(not is_nil(archived_at))
    end

    update :unarchive do
      change set_attribute(:archived_at, nil)
      # if an individual record is used to unarchive
      # it must use the `archived` read action for its atomic upgrade
      atomic_upgrade_with :archived
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
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

    create :register do
      accept [:email]
      change set_attribute(:status, :pending)
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # Sets the email from the argument
      change set_attribute(:email, arg(:email))
      change set_attribute(:status, :pending)

      # Hashes the provided password
      change HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    update :confirm_email do
      accept []
      change set_attribute(:status, :active)
    end

    update :password_reset_with_password do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate PasswordConfirmationValidation

      # Hashes the provided password
      change HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end

    action :request_password_reset_with_password do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end
  end

  policies do
    policy action(:change_password) do
      description "Users can change their own password"
      authorize_if expr(id == ^actor(:id))
    end

    field_policy_bypass :* do
      description "Users can access all fields for password change"
      authorize_if Timeclock.Checks.PasswordChangeInteraction
    end

    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :status, :string do
      allow_nil? false
      public? true
      default :pending
    end

    attribute :hashed_password, :string do
      allow_nil? false
      sensitive? true
    end

    attribute :message, :ci_string do
      allow_nil? true
      public? true
    end
  end

  identities do
    # identity :unique_email, [:email], where: expr(is_nil(archived_at))
    identity :unique_email, [:email]
  end

  relationships do
    has_one :account, Timeclock.Accounts.Account do
      public? true
    end

    has_many :clockings, Timeclock.Clocking.Clocking
    has_many :employees, Timeclock.Accounts.Employee
    has_many :managers, Timeclock.Accounts.Manager
    has_many :roles, Timeclock.Accounts.Role
  end

  preparations do
    prepare build(load: [:account])
  end

  aggregates do
    count :total_clockings, :clockings

    #    sum :clockings_value, [:clockings, :items], :cost do
    #    end
  end
end
