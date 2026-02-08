defmodule Timeclock.Projects.Assignment do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Projects,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :start_date, :utc_datetime do
      public? true
    end

    attribute :end_date, :utc_datetime do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "assignments"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :user, Timeclock.System.Tag do
      public? true
    end

    belongs_to :project, Timeclock.Projects.Project do
      public? true
    end

    belongs_to :role, Timeclock.Accounts.Role do
      public? true
    end
  end

  validations do
    validate present([:start_date, :end_date]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
