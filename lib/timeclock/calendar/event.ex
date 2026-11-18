defmodule Timeclock.Calendar.Event do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calendar,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 150, trim?: true
    end

    attribute :date, :date do
      public? true
      allow_nil? false
    end

    attribute :valid_to, :date do
      public? true
      allow_nil? true
    end

    attribute :recurring_mode, :string do
      public? true
      allow_nil? false
      default "none"
      constraints min_length: 2, max_length: 30, trim?: true
    end

    attribute :type, Timeclock.Type.Event do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_group_event_date, [:group_id, :name, :date]
  end

  relationships do
    belongs_to :group, Timeclock.Calendar.Group do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "calendar_events"
    repo Timeclock.Repo

    references do
      reference :group, on_delete: :delete
    end
  end

  oban do
    triggers do
      # Advances elapsed yearly events forward by 1 year daily at 00:15 UTC
      trigger :rollover_yearly_events do
        action :advance_yearly_occurrence
        where expr(recurring_mode == "yearly" and date < today() and (is_nil(valid_to) or valid_to > date))
        scheduler_cron "15 0 * * *"
        worker_read_action :read
      end
    end
  end

  validations do
    validate one_of(:recurring_mode, ["none", "weekly", "monthly", "yearly"]),
      on: [:create, :update]

    validate compare(:valid_to, greater_than_or_equal_to: :date),
      where: present(:valid_to),
      on: [:create, :update, :advance_yearly_occurrence],
      message: "must be on or after event date"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :date, :valid_to, :recurring_mode, :type, :group_id]
      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendarEvent)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :date, :valid_to, :recurring_mode, :type, :group_id]
      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendarEvent)
    end

    update :advance_yearly_occurrence do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        current_date = Ash.Changeset.get_attribute(changeset, :date)
        valid_to = Ash.Changeset.get_attribute(changeset, :valid_to)
        next_date = Date.shift(current_date, year: 1)

        if is_nil(valid_to) or Date.compare(next_date, valid_to) != :gt do
          Ash.Changeset.force_change_attribute(changeset, :date, next_date)
        else
          Ash.Changeset.add_error(changeset, field: :valid_to, message: "yearly recurrence has expired")
        end
      end

      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendarEvent)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Allow internal AshOban yearly recurrence triggers
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Authenticated users can view calendar events
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete calendar events
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
