defmodule Timeclock.Adjustments.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban]

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
      constraints min: 0, max: 100
    end

    attribute :is_available_for_admins_only, :boolean do
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
    has_many :adjustments, Timeclock.Adjustments.Adjustment do
      public? true
      destination_attribute :definition_id
    end

    belongs_to :account, Timeclock.Accounts.Account do
      public? true
    end

    belongs_to :code, Timeclock.System.Code do
      public? true
      allow_nil? false
    end

    belongs_to :tag, Timeclock.System.Tag do
      public? true
    end
  end

  postgres do
    table "adjustment_definitions"
    repo Timeclock.Repo

    references do
      reference :code, on_delete: :restrict
      reference :tag, on_delete: :nilify
      reference :account, on_delete: :nilify
    end
  end

  oban do
    triggers do
      trigger :apply_periodic_adjustments do
        action :run_periodic_adjustment
        where expr(is_active == true)
        scheduler_cron "0 1 * * *"
        worker_read_action :read
      end
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :type,
        :is_available_for_admins_only,
        :is_active,
        :account_id,
        :code_id,
        :tag_id
      ]

      change run_reactor(Timeclock.Adjustments.Reactors.SetupAdjustmentDefinition)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :type,
        :is_available_for_admins_only,
        :is_active,
        :account_id,
        :code_id,
        :tag_id
      ]

      change run_reactor(Timeclock.Adjustments.Reactors.SetupAdjustmentDefinition)
    end

    update :toggle_active do
      accept [:is_active]
    end

    update :run_periodic_adjustment do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Adjustments.Reactors.ProcessPeriodicAdjustment)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Allow internal AshOban cron triggers without a user actor
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins see all definitions; standard users only see active, non-admin-only definitions
    policy action_type(:read) do
      authorize_if expr(^actor(:role) == :admin)
      authorize_if expr(is_active == true and is_available_for_admins_only == false)
    end

    # Only admins can create, modify, or delete adjustment definitions
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
