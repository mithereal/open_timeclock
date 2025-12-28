defmodule Timeclock.Scheduling.Calendar do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string
    attribute :timezone, :string
    attribute :work_days, {:array, :string}

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "calendars"
    repo Timeclock.Repo
  end

  validations do
    validate present([:name, :timezone, :work_days]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
