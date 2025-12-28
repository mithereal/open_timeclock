defmodule Timeclock.Approvals.RequestLog do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :action, :string
    attribute :date_time, :utc_datetime

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "approval_request_logs"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User
    has_many :requests, Timeclock.Approvals.Request
  end

  validations do
    validate present([:user_id, :action, :date_time]), on: [:create, :update]
    validate string_length(:action, min: 1, max: 255), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
