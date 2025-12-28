defmodule Timeclock.Clocking.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string
    attribute :type, :string
    attribute :code, :string

    attribute :is_active, :boolean, default: true
    attribute :restriction_type, :string

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
    identity :unique_code, [:code]
  end

  postgres do
    table "clocking_definition"
    repo Timeclock.Repo
  end

  relationships do
    has_many :clocking, Timeclock.Clocking.Clocking
    belongs_to :starting_category_definition, Timeclock.Categories.Definition
    belongs_to :absence_category_definition, Timeclock.Categories.Definition
    belongs_to :in_clocking_definition, Timeclock.Clocking.Definition
    belongs_to :out_clocking_definition, Timeclock.Clocking.Definition
    belongs_to :tag, Timeclock.System.Tag
  end

  validations do
    validate present(:name), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
