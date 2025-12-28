defmodule Timeclock.System.Icon do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :uri, :string
  end

  identities do
    identity :unique_id, [:id]
  end

  validations do
    validate present([:name, :uri]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  postgres do
    table "tags"
    repo Timeclock.Repo
  end

  relationships do
    has_many :category_definitions, Timeclock.Categories.Definition
  end
end
