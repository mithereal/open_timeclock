defmodule Timeclock.Audit.LogType do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Audit,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :display_name, :string do
      public? true
    end

    attribute :value, :integer do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "audit_log_types"
    repo Timeclock.Repo
  end

  validations do
    validate present([:display_name, :value]), on: [:create, :update]
    validate string_length(:display_name, min: 1, max: 255), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    has_many :logs, Timeclock.Audit.Log
  end
end
