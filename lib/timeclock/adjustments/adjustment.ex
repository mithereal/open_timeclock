defmodule Timeclock.Adjustments.Adjustment do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :first_name, :string
    attribute :middle_name, :string
    attribute :last_name, :string
    attribute :value, :float
    attribute :timestamp, :utc_datetime

    attribute :calculation_result_type_value_type, :string
    attribute :is_authentic, :boolean, default: false
    attribute :comment, :string
    attribute :status, :string
    attribute :origin, :string
    attribute :inserted_on, :utc_datetime

    # Partial time
    attribute :partial_time_from, :time
    attribute :partial_time_to, :time
    attribute :is_partial, :boolean, default: false
    attribute :partial_time_duration, :float

    # Nested approval request
    attribute :approval_request, :map

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :definition, Timeclock.Adjustments.Definition
    belongs_to :icon, Timeclock.System.Icon
  end

  postgres do
    table "adjustments"
    repo Timeclock.Repo
  end
end
