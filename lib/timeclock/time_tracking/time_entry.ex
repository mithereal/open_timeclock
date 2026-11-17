defmodule Timeclock.TimeTracking.TimeEntry do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.TimeTracking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :timestamp, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :direction, Timeclock.Types.Direction do
      public? true
      allow_nil? false
    end

    attribute :geolocation, Timeclock.TimeTracking.Geolocation do
      public? true
      allow_nil? true
    end

    attribute :dispute_reason, :string do
      public? true
      allow_nil? true
      constraints max_length: 500, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :task, Timeclock.Projects.Task do
      public? true
    end

    belongs_to :clocking, Timeclock.Clocking.Clocking do
      public? true
    end

    belongs_to :modified_by_user, Timeclock.Accounts.User do
      public? true
    end
  end

  postgres do
    table "time_entries"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :task, on_delete: :nilify
      reference :clocking, on_delete: :nilify
      reference :modified_by_user, on_delete: :nilify
    end

    custom_indexes do
      index [:user_id, :timestamp]
    end
  end

  workflow do
    queue :workflow

    step :recorded do
      action :process_entry
      on_success :verified
      on_error :disputed
    end

    step :verified do
      transition :dispute, to: :disputed
      transition :void, to: :voided

      # Flag unclosed/unreconciled entries after 14 hours for manager review
      timeout after: {14, :hours}, action: :flag_stale_entry
    end

    step :disputed do
      transition :resolve_dispute, to: :verified
      transition :void, to: :voided
    end

    step :voided
  end

  actions do
    defaults [:read]

    read :today do
      prepare build(default_sort: [timestamp: :desc])

      filter expr(timestamp >= fragment("date_trunc('day', now() AT TIME ZONE 'UTC')"))
      filter expr(user_id == ^actor(:id))

      pagination offset?: true, default_limit: 20
    end

    create :create do
      primary? true
      accept [:direction, :geolocation, :task_id, :clocking_id]

      # Enforce server-side actor ownership and server clock timestamp
      change relate_actor(:user)
      change set_attribute(:timestamp, &DateTime.utc_now/0)
    end

    create :create_admin do
      description "Admin or system-generated time entry with explicit user and timestamp."
      accept [:user_id, :timestamp, :direction, :geolocation, :task_id, :clocking_id]
      change relate_actor(:modified_by_user)
    end

    update :process_entry do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.TimeTracking.Reactors.ProcessTimeEntry)
      change transition_state(:verified)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:timestamp, :direction, :geolocation, :task_id]
      change relate_actor(:modified_by_user)
    end

    update :dispute do
      accept [:dispute_reason]
      require_atomic? false
      change transition_state(:disputed)
    end

    update :flag_stale_entry do
      accept []
      require_atomic? false
      change set_attribute(:dispute_reason, "Entry exceeded 14-hour threshold without reconciliation")
      change transition_state(:disputed)
    end

    update :resolve_dispute do
      accept [:timestamp, :direction]
      require_atomic? false
      change relate_actor(:modified_by_user)
      change set_attribute(:dispute_reason, nil)
      change transition_state(:verified)
    end

    update :void do
      accept [:dispute_reason]
      require_atomic? false
      change relate_actor(:modified_by_user)
      change transition_state(:voided)
    end

    destroy :destroy do
      primary? true
    end
  end

  calculations do
    calculate :paired_directions,
              {:array, :map},
              Timeclock.TimeTracking.Calculations.PairedDirections do
      argument :entries, {:array, :map}, allow_nil?: false
    end
  end

  policies do
    # Allow internal AshOban workflow workers
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins/managers read all entries; employees only read their own
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Any authenticated user can record their own time entry
    policy action(:create) do
      authorize_if always()
    end

    # Employees can flag/dispute their own time entries
    policy action(:dispute) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Only admins and managers can backfill, edit, resolve disputes, or void entries
    policy action([:create_admin, :update, :resolve_dispute, :void]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Only admins can hard-delete entries
    policy action(:destroy) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
