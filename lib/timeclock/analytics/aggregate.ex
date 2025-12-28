defmodule Timeclock.Analytics.AggregateFunction do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Analytics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :type, :string
    attribute :is_enabled, :boolean, default: true

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "aggregate_functions"
    repo Timeclock.Repo
  end

  validations do
    validate present([:type]), on: [:create, :update]
    validate string_length(:type, min: 1, max: 255), on: [:create, :update]
    validate one_of(:is_enabled, [true, false]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
