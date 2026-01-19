defmodule Timeclock.Scheduling.BreakRule do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :duration_minutes, :integer do
      public? true
    end

    attribute :applies_after_hours, :integer do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "break_rules"
    repo Timeclock.Repo
  end

  validations do
    validate present([:name, :duration_minutes, :applies_after_hours]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
