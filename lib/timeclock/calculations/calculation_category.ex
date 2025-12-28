defmodule Timeclock.Calculations.CalculationCategory do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calculations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string
    attribute :color, :string
    attribute :value, :string

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "calculation_categories"
    repo Timeclock.Repo
  end

  validations do
    validate present(:name), on: [:create, :update]

    validate string_length(:name, min: 1, max: 255), on: [:create, :update]
    validate string_length(:value_type, min: 1, max: 100), on: [:create, :update]
    validate string_length(:color, min: 1, max: 50), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
