defmodule Timeclock.Approvals.Approval do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    # Period info
    attribute :period_start, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :period_end, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :period_options, :map do
      public? true
      allow_nil? false
      default %{}
    end

    # Synchronized status string + dirty tracking
    attribute :status, :string do
      public? true
      allow_nil? false
      default "pending"
      constraints min_length: 2, max_length: 50, trim?: true
    end

    attribute :is_dirty, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :denial_reason, :string do
      public? true
      allow_nil? true
      constraints max_length: 1000, trim?: true
    end

    # Additional data
    attribute :additional_data, Timeclock.Approvals.AdditionalData do
      public? true
      allow_nil? false
    end

    attribute :icon, Timeclock.Types.Icon do
      public? true
      allow_nil? false
    end

    # Partial time
    attribute :is_partial, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :partial_time_from, :time do
      public? true
      allow_nil? true
    end

    attribute :partial_time_to, :time do
      public? true
      allow_nil? true
    end

    # Current approvers
    attribute :current_approver_names, :map do
      public? true
      allow_nil? false
      default %{}
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :status_set_by_user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :request_definition, Timeclock.Approvals.Definition do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "approval_requests"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :status_set_by_user, on_delete: :nilify
      reference :request_definition, on_delete: :restrict
    end
  end

  workflow do
    queue :workflow

    step :pending do
      transition :approve, to: :approved
      transition :deny, to: :denied
      transition :cancel, to: :cancelled

      timeout after: {48, :hours}, action: :send_approver_reminder
      timeout after: {5, :days}, transition_to: :escalated
    end

    step :escalated do
      transition :approve, to: :approved
      transition :deny, to: :denied
    end

    step :approved do
      action :finalize_approval
      on_success :completed
    end

    step :completed
    step :denied
    step :cancelled
  end

  validations do
    validate compare(:period_end, greater_than_or_equal_to: :period_start),
      on: [:create, :update],
      message: "must be on or after period_start"

    validate present([:partial_time_from, :partial_time_to]),
      where: attribute_equals(:is_partial, true),
      on: [:create, :update],
      message: "partial time bounds are required when is_partial is true"

    validate compare(:partial_time_to, greater_than: :partial_time_from),
      where: attribute_equals(:is_partial, true),
      on: [:create, :update],
      message: "must be after partial_time_from"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :period_start,
        :period_end,
        :period_options,
        :additional_data,
        :icon,
        :is_partial,
        :partial_time_from,
        :partial_time_to,
        :current_approver_names,
        :request_definition_id
      ]

      change relate_actor(:user)
      change set_attribute(:status, "pending")
      change set_attribute(:is_dirty, false)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :period_start,
        :period_end,
        :period_options,
        :additional_data,
        :icon,
        :is_partial,
        :partial_time_from,
        :partial_time_to
      ]

      change set_attribute(:is_dirty, true)
    end

    update :approve do
      accept []
      require_atomic? false
      change relate_actor(:status_set_by_user)
      change set_attribute(:status, "approved")
      change set_attribute(:is_dirty, false)
      change transition_state(:approved)
    end

    update :deny do
      accept [:denial_reason]
      require_atomic? false
      change relate_actor(:status_set_by_user)
      change set_attribute(:status, "denied")
      change set_attribute(:is_dirty, false)
      change transition_state(:denied)
    end

    update :cancel do
      accept []
      require_atomic? false
      change set_attribute(:status, "cancelled")
      change transition_state(:cancelled)
    end

    update :send_approver_reminder do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        # Enqueue reminder email/notification via Oban here
        changeset
      end
    end

    update :finalize_approval do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Approvals.Reactors.FinalizeApproval)
      change set_attribute(:status, "completed")
      change transition_state(:completed)
    end

    destroy :destroy do
      primary? true
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

    # Admins/managers view all requests; users view their own requests
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Any authenticated user can submit a request for themselves
    policy action(:create) do
      authorize_if always()
    end

    # Users can edit or cancel their own unapproved requests
    policy action([:update, :cancel]) do
      authorize_if expr(user_id == ^actor(:id) and status == "pending")
    end

    # Only admins and managers can approve or deny requests
    policy action([:approve, :deny]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Only admins can hard-delete approval records
    policy action(:destroy) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
