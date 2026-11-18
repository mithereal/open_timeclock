defmodule Timeclock.Scheduling.Schedule do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Scheduling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :start_time, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :end_time, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :notes, :string do
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
      allow_nil? true
    end

    belongs_to :shift, Timeclock.Scheduling.Shift do
      public? true
      allow_nil? true
    end
  end

  postgres do
    table "schedules"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :nilify
      reference :shift, on_delete: :nilify
    end

    custom_indexes do
      index [:user_id, :start_time]
      index [:start_time, :end_time]
    end
  end

  workflow do
    queue :workflow

    step :scheduled do
      transition :start_shift, to: :in_progress
      transition :cancel, to: :cancelled
    end

    step :in_progress do
      transition :complete_shift, to: :completed
      transition :cancel, to: :cancelled
    end

    step :completed
    step :cancelled
  end

  oban do
    triggers do
      # Transitions scheduled shifts to :in_progress every 5 minutes once start_time arrives
      trigger :activate_due_schedules do
        action :start_shift
        where expr(state == :scheduled and start_time <= now() and end_time > now())
        scheduler_cron "*/5 * * * *"
        worker_read_action :read
      end

      # Closes elapsed shifts to :completed every 15 minutes after end_time passes
      trigger :complete_elapsed_schedules do
        action :complete_shift
        where expr(state in [:scheduled, :in_progress] and end_time <= now())
        scheduler_cron "*/15 * * * *"
        worker_read_action :read
      end
    end
  end

  validations do
    validate compare(:end_time, greater_than: :start_time),
      on: [:create, :update],
      message: "must be after start_time"

    validate fn changeset, _context ->
      start_t = Ash.Changeset.get_attribute(changeset, :start_time)
      end_t = Ash.Changeset.get_attribute(changeset, :end_time)

      if start_t && end_t && DateTime.diff(end_t, start_t, :second) > 86_400 do
        {:error, field: :end_time, message: "single scheduled shift cannot exceed 24 hours"}
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
      accept [:start_time, :end_time, :notes, :user_id, :shift_id]
      change run_reactor(Timeclock.Scheduling.Reactors.SyncSchedule)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:start_time, :end_time, :notes, :user_id, :shift_id]
      change run_reactor(Timeclock.Scheduling.Reactors.SyncSchedule)
    end

    update :start_shift do
      accept []
      require_atomic? false
      change transition_state(:in_progress)
      change run_reactor(Timeclock.Scheduling.Reactors.SyncSchedule)
    end

    update :complete_shift do
      accept []
      require_atomic? false
      change transition_state(:completed)
      change run_reactor(Timeclock.Scheduling.Reactors.SyncSchedule)
    end

    update :cancel do
      accept [:notes]
      require_atomic? false
      change transition_state(:cancelled)
      change run_reactor(Timeclock.Scheduling.Reactors.SyncSchedule)
    end

    destroy :destroy do
      primary? true
      require_atomic? false
    end
  end

  policies do
    # Allow internal AshOban shift lifecycle triggers
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Managers/admins read all schedules; employees see their own shifts and open floating slots
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id) or is_nil(user_id))
    end

    # Only admins and managers can create, reschedule, cancel, or delete roster schedules
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end
  end
end
