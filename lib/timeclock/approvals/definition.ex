defmodule Timeclock.Approvals.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Approvals,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  @allowed_types [0, 1, 2, 3, 4, 5]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :type, :integer do
      public? true
      allow_nil? false
      constraints min: 0, max: 5
    end

    attribute :start_time_parameter_required, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :end_time_parameter_required, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :numeric_value_required, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :time_value_required, :boolean do
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

  relationships do
    has_many :approvals, Timeclock.Approvals.Approval do
      public? true
      destination_attribute :request_definition_id
    end
  end

  postgres do
    table "approval_request_definitions"
    repo Timeclock.Repo
  end

  validations do
    validate one_of(:type, @allowed_types),
      on: [:create, :update],
      message: "must be a valid approval definition type (0..5)"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :type,
        :start_time_parameter_required,
        :end_time_parameter_required,
        :numeric_value_required,
        :time_value_required
      ]

      change run_reactor(Timeclock.Approvals.Reactors.SetupApprovalDefinition)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :type,
        :start_time_parameter_required,
        :end_time_parameter_required,
        :numeric_value_required,
        :time_value_required
      ]

      change run_reactor(Timeclock.Approvals.Reactors.SetupApprovalDefinition)
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

    # Authenticated users can read approval request definitions
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete approval definitions
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
