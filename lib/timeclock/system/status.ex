defmodule Timeclock.System.Status do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :presence_status, :string do
      public? true
      allow_nil? false
      default "neutral"
      constraints min_length: 2, max_length: 50, trim?: true
    end

    attribute :paid_time_status, :string do
      public? true
      allow_nil? false
      default "unpaid"
      constraints min_length: 2, max_length: 50, trim?: true
    end

    attribute :color, :string do
      public? true
      allow_nil? false
      default "#64748B"
      constraints min_length: 4, max_length: 7, trim?: true, match: ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/
    end

    attribute :icon, Timeclock.Types.Icon do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    belongs_to :code, Timeclock.System.Code do
      public? true
      allow_nil? false
    end

    has_many :absences, Timeclock.Absences.Absence do
      public? true
      destination_attribute :status_id
    end
  end

  postgres do
    table "status"
    repo Timeclock.Repo

    references do
      reference :code, on_delete: :restrict
    end
  end

  validations do
    validate one_of(:presence_status, ["present", "absent", "neutral", "on_break"]),
      on: [:create, :update]

    validate one_of(:paid_time_status, ["paid", "unpaid", "partial"]),
      on: [:create, :update]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :presence_status, :paid_time_status, :color, :icon, :code_id]
    end

    update :update do
      primary? true
      accept [:name, :presence_status, :paid_time_status, :color, :icon, :code_id]
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Authenticated users can read system statuses
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete statuses
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
