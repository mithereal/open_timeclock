defmodule Timeclock.Adjustments.Adjustment do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :value, :float do
      public? true
      allow_nil? false
      constraints min: -10_000.0, max: 10_000.0
    end

    attribute :is_authentic, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :comment, :string do
      public? true
      allow_nil? true
      constraints max_length: 1000, trim?: true
    end

    attribute :denial_reason, :string do
      public? true
      allow_nil? true
      constraints max_length: 1000, trim?: true
    end

    attribute :origin, :string do
      public? true
      allow_nil? false
      default "manual"
      constraints min_length: 2, max_length: 50, trim?: true
    end

    attribute :inserted_on, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :partial_time_from, :time do
      public? true
      allow_nil? true
    end

    attribute :partial_time_to, :time do
      public? true
      allow_nil? true
    end

    attribute :is_partial, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :partial_time_duration, :float do
      public? true
      allow_nil? true
      constraints min: 0.0, max: 24.0
    end

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

  relationships do
    belongs_to :account, Timeclock.Accounts.Account do
      public? true
      allow_nil? false
    end

    belongs_to :reviewed_by, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :status, Timeclock.System.Status do
      public? true
      allow_nil? false
    end

    belongs_to :definition, Timeclock.Adjustments.Definition do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "adjustments"
    repo Timeclock.Repo

    references do
      reference :account, on_delete: :delete
      reference :reviewed_by, on_delete: :nilify
      reference :status, on_delete: :restrict
      reference :definition, on_delete: :restrict
    end
  end

  workflow do
    queue :workflow

    step :pending do
      transition :approve, to: :approved
      transition :deny, to: :denied
      transition :cancel, to: :cancelled

      timeout after: {48, :hours}, action: :send_manager_reminder
      timeout after: {5, :days}, transition_to: :escalated
    end

    step :escalated do
      transition :approve, to: :approved
      transition :deny, to: :denied
    end

    step :approved do
      action :apply_adjustment
      on_success :completed
    end

    step :completed
    step :denied
    step :cancelled
  end

  validations do
    validate one_of(:origin, ["manual", "system", "lua_plugin", "payroll_sync", "kiosk"]),
      on: [:create, :create_admin, :update]

    validate present([:partial_time_from, :partial_time_to, :partial_time_duration]),
      where: attribute_equals(:is_partial, true),
      on: [:create, :create_admin, :update],
      message: "partial time fields are required when is_partial is true"

    validate compare(:partial_time_to, greater_than: :partial_time_from),
      where: attribute_equals(:is_partial, true),
      on: [:create, :create_admin, :update],
      message: "must be after partial_time_from"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :value,
        :comment,
        :partial_time_from,
        :partial_time_to,
        :is_partial,
        :partial_time_duration,
        :approval_request,
        :icon,
        :account_id,
        :status_id,
        :definition_id
      ]

      change set_attribute(:is_authentic, false)
      change set_attribute(:origin, "manual")
    end

    # Admin direct creation skips :pending and jumps straight to :approved
    create :create_admin do
      accept [
        :value,
        :comment,
        :origin,
        :inserted_on,
        :partial_time_from,
        :partial_time_to,
        :is_partial,
        :partial_time_duration,
        :approval_request,
        :icon,
        :account_id,
        :status_id,
        :definition_id
      ]

      change set_attribute(:is_authentic, true)
      change relate_actor(:reviewed_by)
      change force_change_attribute(:state, :approved)
    end

    update :approve do
      accept []
      require_atomic? false
      change set_attribute(:is_authentic, true)
      change relate_actor(:reviewed_by)
      change transition_state(:approved)
    end

    update :deny do
      accept [:denial_reason]
      require_atomic? false
      change relate_actor(:reviewed_by)
      change transition_state(:denied)
    end

    update :cancel do
      accept []
      require_atomic? false
      change transition_state(:cancelled)
    end

    update :send_manager_reminder do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        # Enqueue reminder email/notification via Oban here
        changeset
      end
    end

    update :apply_adjustment do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Adjustments.Reactors.ApplyAdjustment)
      change transition_state(:completed)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    bypass always() do
      forbid_unless actor_present()
    end

    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(account.user_id == ^actor(:id))
    end

    policy action(:create) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(account.user_id == ^actor(:id))
    end

    policy action(:cancel) do
      authorize_if expr(account.user_id == ^actor(:id))
    end

    policy action([:create_admin, :approve, :deny]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    policy action(:destroy) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
