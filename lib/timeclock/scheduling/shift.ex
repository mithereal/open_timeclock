defmodule Timeclock.Scheduling.Shift do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string
    attribute :start_time, :time
    attribute :end_time, :time

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "shifts"
    repo Timeclock.Repo
  end

  validations do
    validate present([:name, :start_time, :end_time]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
