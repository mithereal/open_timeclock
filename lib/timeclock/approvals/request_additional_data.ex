defmodule Timeclock.Approvals.RequestAdditionalData do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :integer_value, :string do
      public? true
    end

    attribute :time_value, :time do
      public? true
    end

    attribute :appliers_comment, :string do
      public? true
    end

    attribute :approvers_comment, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "approval_request_additional_data"
    repo Timeclock.Repo
  end

  validations do
    validate compare(:integer_value, less_than_or_equal_to: 50), on: [:create, :update]
    validate string_length(:appliers_comment, min: 1, max: 1000), on: [:create, :update]
    validate string_length(:approvers_comment, min: 1, max: 1000), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
