defmodule Timeclock.Approvals.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string

    attribute :type, :integer do
      public? true
    end

    attribute :start_time_parameter_required, :boolean do
      public? true
      default false
    end

    attribute :end_time_parameter_required, :boolean do
      public? true
      default false
    end

    attribute :numeric_value_required, :boolean do
      public? true
      default false
    end

    attribute :time_value_required, :boolean do
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
    table "approval_request_definitions"
    repo Timeclock.Repo
  end

  @allowed_values [0, 1, 2, 3, 4, 5]

  validations do
    validate present([:name, :request_type]), on: [:create, :update]
    validate string_length(:name, min: 1, max: 255), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  relationships do
    has_many :approvals, Timeclock.Approvals.Approval
  end

  preparations do
    prepare build(load: [:requests])
  end
end
