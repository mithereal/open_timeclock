defmodule Timeclock.Approvals.PermissionDelegation do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :starts_at, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :expires_at, :utc_datetime do
      public? true
      allow_nil? true
    end

    attribute :reason, :string do
      public? true
      allow_nil? true
      constraints max_length: 500, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_delegation_pair, [:user_id, :delegated_user_id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :delegated_user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "approval_permission_delegations"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :delegated_user, on_delete: :delete
    end
  end

  workflow do
    queue :workflow

    step :active do
      transition :revoke, to: :revoked
      transition :expire, to: :expired
    end

    step :revoked
    step :expired
  end

  oban do
    triggers do
      # Automatically expires time-bounded delegations every 15 minutes
      trigger :expire_elapsed_delegations do
        action :expire
        where expr(state == :active and not is_nil(expires_at) and expires_at <= now())
        scheduler_cron "*/15 * * * *"
        worker_read_action :read
      end
    end
  end

  validations do
    validate compare(:expires_at, greater_than: :starts_at),
      where: present(:expires_at),
      on: [:create, :create_for_user, :update],
      message: "must be after starts_at"

    validate fn changeset, _context ->
      user_id = Ash.Changeset.get_attribute(changeset, :user_id)
      delegated_id = Ash.Changeset.get_attribute(changeset, :delegated_user_id)

      if not is_nil(user_id) and user_id == delegated_id do
        {:error, field: :delegated_user_id, message: "cannot delegate permissions to yourself"}
      else
        :ok
      end
    end,
    on: [:create, :create_for_user, :update]
  end

  actions do
    defaults [:read]

    # Manager/Admin delegates their own approval permissions
    create :create do
      primary? true
      accept [:delegated_user_id, :starts_at, :expires_at, :reason]
      change relate_actor(:user)
      change run_reactor(Timeclock.Approvals.Reactors.SyncDelegation)
    end

    # Admin creates a delegation on behalf of another manager
    create :create_for_user do
      accept [:user_id, :delegated_user_id, :starts_at, :expires_at, :reason]
      change run_reactor(Timeclock.Approvals.Reactors.SyncDelegation)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:starts_at, :expires_at, :reason]
      change run_reactor(Timeclock.Approvals.Reactors.SyncDelegation)
    end

    update :revoke do
      accept []
      require_atomic? false
      change transition_state(:revoked)
      change run_reactor(Timeclock.Approvals.Reactors.SyncDelegation)
    end

    update :expire do
      accept []
      require_atomic? false
      change transition_state(:expired)
      change run_reactor(Timeclock.Approvals.Reactors.SyncDelegation)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Allow internal AshOban expiration triggers
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins view all; users view delegations they granted or received
    policy action_type(:read) do
      authorize_if expr(^actor(:role) == :admin)
      authorize_if expr(user_id == ^actor(:id) or delegated_user_id == ^actor(:id))
    end

    # Only managers and admins can delegate approval authority
    policy action(:create) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Only admins can create delegations on behalf of another user or hard-delete
    policy action([:create_for_user, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end

    # Admins or the granting user can update or revoke an active delegation
    policy action([:update, :revoke]) do
      authorize_if expr(^actor(:role) == :admin)
      authorize_if expr(user_id == ^actor(:id))
    end
  end
end
