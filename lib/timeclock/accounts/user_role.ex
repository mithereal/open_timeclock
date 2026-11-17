defmodule Timeclock.Accounts.UserRole do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      primary_key? true
      allow_nil? false
      public? true
    end

    belongs_to :role, Timeclock.Accounts.Role do
      primary_key? true
      allow_nil? false
      public? true
    end
  end

  postgres do
    table "user_roles"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :role, on_delete: :restrict
    end

    custom_indexes do
      index [:role_id]
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:user_id, :role_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncUserRole)
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate fn changeset, %{actor: actor} ->
        if actor && changeset.data.user_id == actor.id do
          {:error, field: :user_id, message: "cannot revoke your own role assignment"}
        else
          :ok
        end
      end

      change run_reactor(Timeclock.Accounts.Reactors.SyncUserRole)
    end
  end

  policies do
    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins/managers read all assignments; users only read their own assigned roles
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Only admins can grant or revoke user role assignments
    policy action_type([:create, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
