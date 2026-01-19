defmodule Timeclock.Approvals.PermissionDelegation do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "approval_permission_delegations"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :delegated_user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :user, Timeclock.Accounts.User do
      public? true
    end
  end

  validations do
    validate present([:delegated_user_id, :user_id]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
