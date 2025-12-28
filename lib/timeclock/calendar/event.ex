defmodule Timeclock.Calendar.Event do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calendar,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string
    attribute :date, :date
    attribute :valid_to, :date

    attribute :recurring_mode, :string

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "calendar_events"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :group, Timeclock.Calendar.Group
    belongs_to :event_type, Timeclock.Calendar.EventType
  end

  validations do
    validate present([:name, :date]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
