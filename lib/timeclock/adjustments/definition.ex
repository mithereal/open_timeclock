defmodule Timeclock.Adjustments.Definition do
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

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :type, :string do
      public? true
      allow_nil? false
    end

    attribute :code, :string do
      public? true
      allow_nil? false
    end

    # Flags
    attribute :is_available_for_admins_only, :boolean do
      public? true
      default false
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

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
    belongs_to :tags, Timeclock.System.Tag
    belongs_to :restriction, Timeclock.Absences.Restriction
    belongs_to :caculation_result, Timeclock.Calculation.CalculationDetail
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
