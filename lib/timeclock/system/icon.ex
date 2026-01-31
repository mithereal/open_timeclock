defmodule Timeclock.System.Icon do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :uri, :string do
      public? true
    end
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
    table "icons"
    repo Timeclock.Repo
  end

  relationships do
    has_many :categories, Timeclock.System.Category
  end
end
