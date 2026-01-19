defmodule Timeclock.Scheduling.Schedule do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :start_time, :utc_datetime do
      public? true
    end

    attribute :end_time, :utc_datetime do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "schedules"
    repo Timeclock.Repo
  end

  validations do
    validate present([:start_time, :end_time]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :shift, Timeclock.Scheduling.Shift do
      public? true
    end
  end
end
