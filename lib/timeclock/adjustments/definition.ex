defmodule Timeclock.Adjustments.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :first_name, :string

    attribute :name, :string
    attribute :type, :string
    attribute :code, :string

    # Calculation result type
    attribute :calculation_result_type_id, :uuid
    attribute :calculation_result_type_name, :string
    attribute :calculation_result_type_value_type, :string

    # Flags
    attribute :is_available_for_admins_only, :boolean, default: false
    attribute :is_active, :boolean, default: true

    # Restrictions
    attribute :restriction_type, :string
    attribute :tag_id, :uuid

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "adjustment_definitions"
    repo Timeclock.Repo
  end

  relationships do
    has_many :adjustments, Timeclock.Adjustments.Adjustment
  end

  validations do
    validate present([:name, :type]), on: [:create, :update]
    validate string_length(:name, min: 1, max: 255), on: [:create, :update]
    validate string_length(:type, min: 1, max: 100), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
