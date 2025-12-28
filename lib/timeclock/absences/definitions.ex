defmodule Timeclock.Absences.Definitions do
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
    attribute :requires_approval, :boolean
    attribute :max_days_per_year, :integer
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "absence_definitions"
    repo Timeclock.Repo
  end
end
