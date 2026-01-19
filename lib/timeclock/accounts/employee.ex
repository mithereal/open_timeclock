defmodule Timeclock.Accounts.Employee do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :position, :string do
      public? true
      allow_nil? false
    end

    attribute :hired_at, :string do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :department, Timeclock.Organizations.Department
  end

  postgres do
    table "employees"
    repo Timeclock.Repo
  end
end
