defmodule Timeclock.Audit.Log do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Audit,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :table_name, :string
    attribute :ip_address, :string
    attribute :action, :string
    attribute :date_time, :utc_datetime
    attribute :old_value, :map
    attribute :new_value, :map

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "audit_logs"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :account, Timeclock.Accounts.Account
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :log_type, Timeclock.Audit.LogType
  end

  validations do
    validate present([:table_name, :date_time]), on: [:create, :update]
    validate string_length(:ip_address, min: 1, max: 45), on: [:create, :update]
    validate string_length(:action, min: 1, max: 100), on: [:create, :update]
    validate string_length(:table_name, min: 1, max: 255), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
