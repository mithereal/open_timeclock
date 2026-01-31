defmodule Timeclock.Analytics.Activity do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Analytics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :properties, :map do
      public? true
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "analytics_activities"
    repo Timeclock.Repo
  end

  validations do
    validate present([:name]), on: [:create, :update]
    validate string_length(:name, min: 1, max: 255), on: [:create, :update]
    # validate {Timeclock.Validations.Properties, [:properties]}, on: :create
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
