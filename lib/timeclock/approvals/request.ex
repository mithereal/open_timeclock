defmodule Timeclock.Approvals.Request do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    # Period info
    attribute :period_start, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :period_end, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :period_options, :map do
      public? true
      allow_nil? false
    end

    # Status info
    attribute :status, :string do
      public? true
      allow_nil? false
    end

    attribute :is_dirty, :boolean do
      public? true
      default false
    end

    # Additional data
    attribute :additional_data, :map do
      public? true
      allow_nil? false
    end

    # Partial time
    attribute :is_partial, :boolean do
      public? true
      default false
    end

    attribute :partial_time_from, :time
    attribute :partial_time_to, :time

    # Current approvers
    attribute :current_approver_names, :map

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "approval_requests"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :status_set_by_user, Timeclock.Accounts.User
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :icon, Timeclock.System.Icon
    belongs_to :request_definition, Timeclock.Approvals.RequestDefinition
    belongs_to :request_additional_data, Timeclock.Approvals.RequestAdditionalData
    belongs_to :request_log, Timeclock.Approvals.RequestLog
  end

  validations do
    validate present([:user_id, :period_start]), on: [:create, :update]
    validate one_of(:is_partial, [true, false]), on: [:create, :update]
    validate one_of(:is_dirty, [true, false]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
