defmodule Timeclock.TimeTracking.Geolocation do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.TimeTracking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :latitude, :float
    attribute :longitude, :float
    attribute :recorded_at, :utc_datetime

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "geolocations"
    repo Timeclock.Repo
  end

  validations do
    validate present([:latitude, :longitude, :recorded_at]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
