defmodule Timeclock.TimeTracking.TimeEntry do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.TimeTracking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :clock_in, :utc_datetime
    attribute :clock_out, :utc_datetime
    attribute :total_hours, :float

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "time_entries"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :task, Timeclock.Projects.Task
  end

  validations do
    validate present([:clock_in, :clock_out, :total_hours]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
