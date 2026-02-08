defmodule Timeclock.Calendar.Calendar do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calendar,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :timezone, :string do
      public? true
    end

    attribute :work_days, {:array, :string} do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "calendars"
    repo Timeclock.Repo
  end

  validations do
    validate present([:name, :timezone, :work_days]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  actions do
    default_accept :*

    defaults [:read, :update]

    create :init do
      accept []
    end

    read :get do
      get? true
    end
  end
end
