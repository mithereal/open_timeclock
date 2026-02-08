defmodule Timeclock.Projects.Task do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Projects,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :due_date, :utc_datetime do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "tasks"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :assignment, Timeclock.Projects.Assignment do
      public? true
    end

    belongs_to :project, Timeclock.Projects.Project do
      public? true
    end

    belongs_to :task, Timeclock.Projects.Task do
      public? true
    end
  end

  validations do
    validate present([:name, :description, :due_date]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
