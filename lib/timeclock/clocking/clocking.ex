defmodule Timeclock.Clocking.Clocking do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :timestamp, :utc_datetime
    attribute :original_timestamp, :utc_datetime
    attribute :is_authentic, :boolean, default: false
    attribute :comment, :string
    attribute :status, :string
    attribute :geo_location_timestamp, :utc_datetime
    attribute :has_geo_location, :boolean, default: false
    attribute :accuracy, :float

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "clockings"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :modified_by_user, Timeclock.Accounts.User
    belongs_to :device, Timeclock.Clocking.Device
    belongs_to :beacon, Timeclock.Clocking.Beacon
    belongs_to :point, Timeclock.Clocking.Point
    belongs_to :definition, Timeclock.Clocking.Definition
    belongs_to :interface_detail, Timeclock.Clocking.InterfaceDetail
    belongs_to :origin, Timeclock.Clocking.Origin
    belongs_to :original_clocking_definition, Timeclock.Clocking.Definition
    belongs_to :approval_request, Timeclock.Approvals.Request
  end

  validations do
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
