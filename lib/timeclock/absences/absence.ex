defmodule Timeclock.Absences.Absence do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :start_date, :utc_datetime
    attribute :end_date, :utc_datetime
    attribute :status, :string
    attribute :reason, :string
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :approved_by, Timeclock.Accounts.User
    belongs_to :absence_definition, Timeclock.Absences.Definition
  end

  postgres do
    table "absences"
    repo Timeclock.Repo
  end
end
