defmodule Timeclock.Locations.Address do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Locations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :line, :string
    attribute :city, :string
    attribute :country, :string
    attribute :postal_code, :string
    attribute :state, :string
    attribute :ip_address, :string

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "addresses"
    repo Timeclock.Repo
  end

  validations do
    validate present([:line, :city, :country]), on: [:create, :update]
    validate string_length(:line, min: 1, max: 255), on: [:create, :update]
    validate string_length(:city, min: 1, max: 100), on: [:create, :update]
    validate string_length(:state, min: 1, max: 100), on: [:create, :update]
    validate string_length(:country, min: 1, max: 100), on: [:create, :update]
    validate string_length(:postal_code, min: 1, max: 20), on: [:create, :update]

    validate match(:ip_address, ~r/^(\d{1,3}\.){3}\d{1,3}$|^[a-fA-F0-9:]+$/),
      on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
