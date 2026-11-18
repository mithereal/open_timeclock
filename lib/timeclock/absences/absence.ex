defmodule Timeclock.Absences.Absence do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Absences,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :start_date, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :end_date, :utc_datetime do
      public? true
      allow_nil? false
    end

    attribute :reason, :string do
      public? true
      allow_nil? false
      constraints min_length: 3, max_length: 1000, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? false
    end

    belongs_to :status, Timeclock.System.Status do
      public? true
      allow_nil? false
    end

    belongs_to :approved_by, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :absence_definition, Timeclock.Absences.Definition do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "absences"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :absence_definition, on_delete: :restrict
    end
  end

  validations do
    validate compare(:end_date, greater_than: :start_date),
      message: "must be after start date"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      # Only accept safe user-facing fields; bind user_id from the logged-in actor
      accept [:start_date, :end_date, :reason, :absence_definition_id]
      change relate_actor(:user)
    end

    update :approve do
      accept [:status_id]
      require_atomic? false
      change relate_actor(:approved_by)
    end

    update :cancel do
      accept []
      require_atomic? false
      # Only allow cancelling if not yet approved
      validate attribute_equals(:approved_by_id, nil),
        message: "cannot cancel an already reviewed absence"
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Require an authenticated actor for all actions
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins and managers can read all absences; employees only read their own
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Any authenticated employee can create an absence for themselves
    policy action(:create) do
      authorize_if always()
    end

    # Employees can cancel their own unreviewed requests
    policy action(:cancel) do
      authorize_if expr(user_id == ^actor(:id))
    end

    # Only admins and managers can approve/update status
    policy action(:approve) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end

    # Only admins can hard-delete records
    policy action(:destroy) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
