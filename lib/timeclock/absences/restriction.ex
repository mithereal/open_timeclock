defmodule Timeclock.Absences.Restriction do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :description, :string
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "absence_restrictions"
    repo Timeclock.Repo
  end
end
