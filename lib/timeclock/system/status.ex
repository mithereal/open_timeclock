defmodule Timeclock.System.Status do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :presence_status, :string do
      public? true
    end

    attribute :paid_time_status, :string do
      public? true
    end

    attribute :color, :string do
      public? true
    end

    attribute :icon, Timeclock.Types.Icon do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "status"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :code, Timeclock.System.Code do
      public? true
    end
  end

  validations do
    validate present(:name), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
