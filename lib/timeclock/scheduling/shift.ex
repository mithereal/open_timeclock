defmodule Timeclock.Scheduling.Shift do
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

    attribute :start_time, :time do
      public? true
      allow_nil? false
    end

    attribute :end_time, :time do
      public? true
      allow_nil? false
    end

    attribute :is_overnight, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :is_active, :boolean do
      public? true
      allow_nil? false
      default true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    belongs_to :break_rule, Timeclock.Scheduling.BreakRule do
      public? true
      allow_nil? true
    end

    has_many :schedules, Timeclock.Scheduling.Schedule do
      public? true
      destination_attribute :shift_id
    end
  end

  postgres do
    table "shifts"
    repo Timeclock.Repo

    references do
      reference :break_rule, on_delete: :nilify
    end
  end

  validations do
    validate fn changeset, _context ->
      s = Ash.Changeset.get_attribute(changeset, :start_time)
      e = Ash.Changeset.get_attribute(changeset, :end_time)

      if s && e && Time.compare(s, e) == :eq do
        {:error, field: :end_time, message: "end_time must differ from start_time"}
      else
        :ok
      end
    end,
    on: [:create, :update]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :start_time, :end_time, :is_active, :break_rule_id]
      change &__MODULE__.derive_overnight_flag/2
      change run_reactor(Timeclock.Scheduling.Reactors.SyncShift)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :start_time, :end_time, :is_active, :break_rule_id]
      change &__MODULE__.derive_overnight_flag/2
      change run_reactor(Timeclock.Scheduling.Reactors.SyncShift)
    end

    update :toggle_active do
      accept [:is_active]
      change run_reactor(Timeclock.Scheduling.Reactors.SyncShift)
    end

    destroy :destroy do
      primary? true
    end
  end

  @doc false
  def derive_overnight_flag(changeset, _context) do
    s = Ash.Changeset.get_attribute(changeset, :start_time)
    e = Ash.Changeset.get_attribute(changeset, :end_time)

    if s && e do
      Ash.Changeset.force_change_attribute(changeset, :is_overnight, Time.compare(e, s) == :lt)
    else
      changeset
    end
  end

  policies do
    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins see all shift templates; managers and employees see active templates
    policy action_type(:read) do
      authorize_if expr(^actor(:role) == :admin)
      authorize_if expr(is_active == true)
    end

    # Only admins can create, modify, or delete shift templates
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
