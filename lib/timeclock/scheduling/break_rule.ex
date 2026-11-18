defmodule Timeclock.Scheduling.BreakRule do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Scheduling,
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

    attribute :duration_minutes, :integer do
      public? true
      allow_nil? false
      constraints min: 1, max: 480
    end

    attribute :applies_after_hours, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :threshold_hours, :float do
      public? true
      allow_nil? true
      default 4.0
      constraints min: 0.5, max: 24.0
    end

    attribute :is_paid, :boolean do
      public? true
      allow_nil? false
      default false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  postgres do
    table "break_rules"
    repo Timeclock.Repo
  end

  validations do
    validate present(:threshold_hours),
      where: attribute_equals(:applies_after_hours, true),
      on: [:create, :update],
      message: "threshold_hours is required when applies_after_hours is true"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :duration_minutes, :applies_after_hours, :threshold_hours, :is_paid]
      change run_reactor(Timeclock.Scheduling.Reactors.SyncBreakRule)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :duration_minutes, :applies_after_hours, :threshold_hours, :is_paid]
      change run_reactor(Timeclock.Scheduling.Reactors.SyncBreakRule)
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

    # Authenticated users can read break rules
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete break rules
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
