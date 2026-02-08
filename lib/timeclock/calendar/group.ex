defmodule Timeclock.Calendar.Group do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calendar,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :workdays, :map do
      public? true
    end

    attribute :time_zone, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "calendar_groups"
    repo Timeclock.Repo
  end

  validations do
    validate present(:name), on: [:create, :update]
    validate present(:workdays), on: [:create, :update]
    validate present(:time_zone), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    has_many :events, Timeclock.Calendar.Event
  end
end
