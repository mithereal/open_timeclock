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
    attribute :period_start, :utc_datetime
    attribute :period_end, :utc_datetime
    attribute :period_options, :map

    # Status info
    attribute :status, :string
    attribute :status_set_by_user, :string
    attribute :is_dirty, :boolean, default: false

    # Additional data
    attribute :additional_data, :map

    # Partial time
    attribute :is_partial, :boolean, default: false
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
    belongs_to :status_set_by_user_id, Timeclock.Accounts.User
    belongs_to :user, Timeclock.Accounts.User
    belongs_to :icon, Timeclock.System.Icon
    belongs_to :request_definition, Timeclock.Approvals.RequestDefinition
    belongs_to :request_additiona_data, Timeclock.Approvals.RequestAdditionalData
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
