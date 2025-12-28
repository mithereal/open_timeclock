defmodule Timeclock.Calculations.Calculation do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calculations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :date_from, :date
    attribute :date_to, :date
    attribute :users_count, :integer
    attribute :users_calculations, :map
    attribute :calculation_details_summaries, :map

    attribute :plan_sum_value, :decimal
    attribute :difference_sum_value, :decimal
    attribute :paid_presence_sum_value, :decimal
    attribute :paid_all_day_absence_sum_value, :decimal
    attribute :missing_presence_sum_value, :decimal
    attribute :unpaid_presence_sum_value, :decimal
    attribute :work_free_days_sum_value, :decimal
    attribute :work_days_sum_value, :decimal

    attribute :is_calculation_valid, :boolean, default: false

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
