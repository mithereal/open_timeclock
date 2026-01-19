defmodule Timeclock.Clocking.InterfaceDetail do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :button_index, :integer
    attribute :event_index, :integer

    attribute :is_default, :boolean do
      public? true
      default false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "clocking_interface_details"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :definition, Timeclock.Clocking.Definition
    belongs_to :icon, Timeclock.System.Icon
    belongs_to :tag, Timeclock.System.Tag
    has_many :clockings, Timeclock.Clocking.Clocking
  end

  validations do
    validate present([:button_index, :event_index, :clocking_definition_id]),
      on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
