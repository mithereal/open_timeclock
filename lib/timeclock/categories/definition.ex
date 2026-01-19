defmodule Timeclock.Categories.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Categories,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :presence_status, :string do
      public? true
    end

    attribute :paid_time_status, :string do
      public? true
    end

    attribute :color, :string do
      public? true
    end

    attribute :code, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
    identity :unique_code, [:code]
  end

  postgres do
    table "category_definitions"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :icon, Timeclock.System.Icon do
      public? true
    end
  end

  validations do
    validate present(:name), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
