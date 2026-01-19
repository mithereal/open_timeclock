defmodule Timeclock.System.Code do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :code, :string do
      public? true
    end
  end

  identities do
    identity :unique_id, [:id]
    identity :unique_code, [:code]
  end

  validations do
    validate present([:code]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  postgres do
    table "codes"
    repo Timeclock.Repo
  end
end
