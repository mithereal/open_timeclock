defmodule Timeclock.Adjustments.Adjustment do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :value, :float do
      public? true
      allow_nil? false
    end

    attribute :is_authentic, :boolean do
      public? true
      default false
    end

    attribute :comment, :string do
      public? true
      allow_nil? true
    end

    attribute :origin, :string do
      public? true
      allow_nil? true
    end

    attribute :inserted_on, :utc_datetime

    # Partial time
    attribute :partial_time_from, :time do
      public? true
      allow_nil? true
    end

    attribute :partial_time_to, :time do
      public? true
      allow_nil? true
    end

    attribute :is_partial, :boolean, default: false

    attribute :partial_time_duration, :float do
      public? true
      allow_nil? true
    end

    # Nested approval request
    attribute :approval_request, :map do
      public? true
      allow_nil? true
    end

    attribute :icon, Timeclock.Types.Icon do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :account, Timeclock.Accounts.Account do
      public? true
    end

    belongs_to :status, Timeclock.System.Status do
      public? true
    end

    belongs_to :definition, Timeclock.Adjustments.Definition do
      public? true
    end
  end

  postgres do
    table "adjustments"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  preparations do
    prepare build(load: [:status, :account, :icon, :definition])
  end
end
