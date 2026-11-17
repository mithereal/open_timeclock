defmodule Timeclock.Accounts.Employee do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :position, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 120, trim?: true
    end

    attribute :hired_at, :date do
      public? true
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :terminated_at, :date do
      public? true
      allow_nil? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_user_employee, [:user_id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :department, Timeclock.Organizations.Department do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "employees"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :department, on_delete: :restrict
    end

    custom_indexes do
      index [:department_id]
    end
  end

  workflow do
    queue :workflow

    step :onboarding do
      action :complete_onboarding
      on_success :active
    end

    step :active do
      transition :place_on_leave, to: :on_leave
      transition :terminate, to: :terminated
    end

    step :on_leave do
      transition :return_from_leave, to: :active
      transition :terminate, to: :terminated
    end

    step :terminated
  end

  oban do
    triggers do
      # Automatically transitions employees to :terminated once their scheduled terminated_at date arrives
      trigger :process_scheduled_terminations do
        action :terminate
        where expr(state in [:active, :on_leave] and not is_nil(terminated_at) and terminated_at <= today())
        scheduler_cron "15 0 * * *"
        worker_read_action :read
      end
    end
  end

  validations do
    validate compare(:terminated_at, greater_than_or_equal_to: :hired_at),
      where: present(:terminated_at),
      on: [:create, :update, :terminate],
      message: "must be on or after hired_at"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:position, :hired_at, :terminated_at, :user_id, :department_id]
    end

    update :complete_onboarding do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Accounts.Reactors.SyncEmployee)
      change transition_state(:active)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:position, :hired_at, :terminated_at, :department_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncEmployee)
    end

    update :promote_or_transfer do
      description "Updates an employee's position or department and triggers HR/Lua sync hooks."
      require_atomic? false
      accept [:position, :department_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncEmployee)
    end

    update :place_on_leave do
      accept []
      require_atomic? false
      change transition_state(:on_leave)
      change run_reactor(Timeclock.Accounts.Reactors.SyncEmployee)
    end

    update :return_from_leave do
      accept []
      require_atomic? false
      change transition_state(:active)
      change run_reactor(Timeclock.Accounts.Reactors.SyncEmployee)
    end

    update :terminate do
      accept [:terminated_at]
      require_atomic? false

      change fn changeset, _context ->
        if is_nil(Ash.Changeset.get_attribute(changeset, :terminated_at)) do
          Ash.Changeset.force_change_attribute(changeset, :terminated_at, Date.utc_today())
        else
          changeset
        end
      end

      change transition_state(:terminated)
      change run_reactor(Timeclock.Accounts.Reactors.SyncEmployee)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Allow internal AshOban lifecycle triggers
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins/managers view all employees; employees only view their own record
    policy action(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Managers and admins can place employees on leave or return them from leave
    policy action([:place_on_leave, :return_from_leave]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Only admins can hire, edit, transfer, terminate, or delete employee records
    policy action([:create, :update, :promote_or_transfer, :terminate, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
