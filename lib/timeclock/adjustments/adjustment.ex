defmodule Timeclock.Adjustments.Adjustment do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      public? true
      allow_nil? false
    end

    attribute :middle_name, :string do
      public? true
      allow_nil? false
    end

    attribute :last_name, :string do
      public? true
      allow_nil? false
    end

    attribute :value, :float do
      public? true
      allow_nil? false
    end

    attribute :is_authentic, :boolean do
      public? true
      default false
    end

    attribute :comment, :string do
      public? true
      allow_nil? true
    end

    attribute :status, :string do
      public? true
      allow_nil? true
    end

    attribute :origin, :string do
      public? true
      allow_nil? true
    end

    attribute :inserted_on, :utc_datetime

    # Partial time
    attribute :partial_time_from, :time do
      public? true
      allow_nil? true
    end

    attribute :partial_time_to, :time do
      public? true
      allow_nil? true
    end

    attribute :is_partial, :boolean, default: false

    attribute :partial_time_duration, :float do
      public? true
      allow_nil? true
    end

    # Nested approval request
    attribute :approval_request, :map do
      public? true
      allow_nil? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :definition, Timeclock.Adjustments.Definition
    belongs_to :calculation_result, Timeclock.Calculations.CalculationDetail
    belongs_to :icon, Timeclock.System.Icon
  end

  postgres do
    table "adjustments"
    repo Timeclock.Repo
  end
end
