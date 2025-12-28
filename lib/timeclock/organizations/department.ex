defmodule Timeclock.Organizations.Department do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "departments"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :starting_category_definition, Timeclock.Categories.Definition
    belongs_to :absence_category_definition, Timeclock.Categories.Definition
    belongs_to :in_clocking_definition, Timeclock.Clocking.Definition
    belongs_to :out_clocking_definition, Timeclock.Clocking.Definition

    belongs_to :company, Timeclock.Organizations.Company
  end

  validations do
    validate present([:name]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
