defmodule Timeclock.Absences.Absence do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :start_date, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :end_date, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :status, :string do
      public? true
      allow_nil? false
    end

    attribute :reason, :string do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :approved_by, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :absence_definition, Timeclock.Absences.Definition do
      public? true
    end
  end

  postgres do
    table "absences"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
