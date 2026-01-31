defmodule Timeclock.System.Address do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :street, :string do
      public? true
    end

    attribute :city, :string do
      public? true
    end

    attribute :state, :string do
      public? true
    end

    attribute :postal_code, :string do
      public? true
    end

    attribute :country, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "addresses"
    repo Timeclock.Repo
  end

  validations do
    validate present([:street, :city, :state, :postal_code, :country]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    belongs_to :company, Timeclock.Organizations.Company
  end
end
