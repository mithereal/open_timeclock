defmodule Timeclock.Clocking.Point do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Audit,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :value, :integer do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "points"
    repo Timeclock.Repo
  end

  validations do
    validate present([:name, :value]), on: [:create, :update]
    validate string_length(:name, min: 1, max: 255), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    has_many :clockings, Timeclock.Clocking.Clocking
  end
end
