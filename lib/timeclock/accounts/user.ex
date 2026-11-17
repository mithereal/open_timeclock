defmodule Timeclock.Accounts.User do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [
      AshAuthentication,
      AshArchival.Resource,
      AshAdmin.Resource,
      AshWorkflow,
      AshOban
    ]

  alias AshAuthentication.Strategy.Password.HashPasswordChange
  alias AshAuthentication.Strategy.Password.PasswordConfirmationValidation

  admin do
    actor? true
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :role, :atom do
      allow_nil? false
      public? true
      default :employee
      constraints one_of: [:admin, :manager, :employee, :kiosk]
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :active, :suspended, :archived]
    end

    attribute :hashed_password, :string do
      allow_nil? true
      public? false
      sensitive? true
    end

    attribute :message, :ci_string do
      allow_nil? true
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
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

  aggregates do
    count :total_clockings, :clockings
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
    exclude_read_actions [:archived]
    archive_related [:account]
    archive_related_authorize? false
  end

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
      end
    end
  end

  workflow do
    queue :workflow

    step :pending do
      transition :confirm_email, to: :active
      transition :suspend, to: :suspended

      # Purge/archive unconfirmed self-registrations after 7 days
      timeout after: {7, :days}, action: :expire_unconfirmed
    end

    step :active do
      transition :suspend, to: :suspended
    end

    step :suspended do
      transition :reactivate, to: :active
    end

    step :expired
  end

  actions do
    defaults [:read, :destroy]

    read :list do
      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end

    read :archived do
      filter expr(not is_nil(archived_at))
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT."
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email."
      get_by :email
    end

    read :sign_in_with_token do
      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_password do
      description "Attempt to sign in using an email and password."
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

      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with a magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user."
        allow_nil? false
        sensitive? true
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token."
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      change AshAuthentication.Strategy.MagicLink.SignInChange

      change {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenChange,
              strategy_name: :remember_me}

      change set_attribute(:status, :active)
      change force_change_attribute(:state, :active)

      metadata :token, :string do
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with an email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 12, max_length: 72
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      change set_attribute(:email, arg(:email))
      change set_attribute(:status, :pending)
      change set_attribute(:role, :employee)
      change HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      validate PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    update :confirm_email do
      accept []
      require_atomic? false
      change set_attribute(:status, :active)
      change transition_state(:active)
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
    end

    update :change_password do
      description "Allows an authenticated user to change their own password."
      require_atomic? false

      argument :current_password, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        allow_nil? false
        constraints min_length: 12, max_length: 72
        sensitive? true
      end

      argument :password_confirmation, :string do
        allow_nil? false
        sensitive? true
      end

      validate AshAuthentication.Strategy.Password.PasswordValidation
      validate PasswordConfirmationValidation
      change HashPasswordChange
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
    end

    update :password_reset_with_password do
      require_atomic? false

      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 12, max_length: 72
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      validate AshAuthentication.Strategy.Password.ResetTokenValidation
      validate PasswordConfirmationValidation
      change HashPasswordChange
      change AshAuthentication.GenerateTokenChange
      change set_attribute(:status, :active)
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
    end

    update :update_role do
      description "Admin-only role assignment."
      accept [:role]
      require_atomic? false
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
    end

    update :suspend do
      accept []
      require_atomic? false
      change set_attribute(:status, :suspended)
      change transition_state(:suspended)
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
    end

    update :reactivate do
      accept []
      require_atomic? false
      change set_attribute(:status, :active)
      change transition_state(:active)
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
    end

    update :expire_unconfirmed do
      accept []
      require_atomic? false
      change set_attribute(:status, :archived)
      change transition_state(:expired)
    end

    update :unarchive do
      accept []
change set_attribute(:archived_at, nil)
change set_attribute(:status, :active)
atomic_upgrade_with :archived
change run_reactor(Timeclock.Accounts.Reactors.SyncUserLifecycle)
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
run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
end
end
policies do
# Allow internal AshAuthentication flows (login, registration, confirmation, reset)
bypass AshAuthentication.Checks.AshAuthenticationInteraction do
authorize_if always()
end
# Allow internal AshOban workflow deadline workers
bypass AshOban.Checks.AshObanInteraction do
authorize_if always()
end
# Block anonymous access on all remaining actions
bypass always() do
forbid_unless actor_present()
end
# Admins/managers read all users; employees only read their own user record
policy action([:read, :list]) do
authorize_if expr(^actor(:role) in [:admin, :manager])
authorize_if expr(id == ^actor(:id))
end
# Users can change their own password
policy action(:change_password) do
authorize_if expr(id == ^actor(:id) and status == :active)
end
# Only admins can view archived users, unarchive, change roles, suspend, reactivate, or archive/destroy
policy action([:archived, :unarchive, :update_role, :suspend, :reactivate, :destroy]) do
authorize_if expr(^actor(:role) == :admin)
end
end
end