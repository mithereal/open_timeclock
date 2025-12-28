defmodule Timeclock.Organizations.Organization do
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
    table "organizations"
    repo Timeclock.Repo
  end

  relationships do
    has_one :company, Timeclock.Organizations.Company
  end

  validations do
    validate present([:name]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
