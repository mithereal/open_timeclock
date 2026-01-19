defmodule Timeclock.Calculations.Calculation do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calculations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :date_from, :date do
      public? true
    end

    attribute :date_to, :date do
      public? true
    end

    attribute :users_count, :integer do
      public? true
    end

    attribute :users_calculations, :map do
      public? true
    end

    attribute :calculation_details_summaries, :map do
      public? true
    end

    attribute :plan_sum_value, :decimal do
      public? true
    end

    attribute :difference_sum_value, :decimal do
      public? true
    end

    attribute :paid_presence_sum_value, :decimal do
      public? true
    end

    attribute :paid_all_day_absence_sum_value, :decimal do
      public? true
    end

    attribute :missing_presence_sum_value, :decimal do
      public? true
    end

    attribute :unpaid_presence_sum_value, :decimal do
      public? true
    end

    attribute :work_free_days_sum_value, :decimal do
      public? true
    end

    attribute :work_days_sum_value, :decimal do
      public? true
    end

    attribute :is_calculation_valid, :boolean do
      public? true
      default false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "calculations"
    repo Timeclock.Repo
  end

  validations do
    validate present([:date_from, :date_to]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
