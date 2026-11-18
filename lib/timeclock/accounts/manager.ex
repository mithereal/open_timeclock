defmodule Timeclock.Accounts.Manager do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_department_manager, [:user_id, :department_id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :department, Timeclock.Organizations.Department do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "managers"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :department, on_delete: :restrict
    end

    custom_indexes do
      index [:department_id]
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:user_id, :department_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncManager)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:department_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncManager)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Authenticated users can view department manager assignments
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can assign, reassign, or remove department managers
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
