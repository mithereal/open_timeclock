defmodule Timeclock.System.Tag do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end
  end

  identities do
    identity :unique_id, [:id]
  end

  validations do
    validate present([:name]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  postgres do
    table "tags"
    repo Timeclock.Repo
  end
end
