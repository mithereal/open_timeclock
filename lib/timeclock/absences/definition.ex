defmodule Timeclock.Absences.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Absences,
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

    attribute :type, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 50, trim?: true
    end

    attribute :max_days_per_year, :integer do
      public? true
      allow_nil? false
      constraints min: 0, max: 366
    end

    attribute :fraction, :integer do
      public? true
      allow_nil? false
      default 100
      constraints min: 1, max: 100
    end

    attribute :active, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :available_for_admins_only, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :description, :string do
      public? true
      allow_nil? false
      constraints min_length: 3, max_length: 1000, trim?: true
    end

    attribute :requires_approval, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :icon, Timeclock.Types.Icon do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    belongs_to :code, Timeclock.System.Code do
      public? true
      allow_nil? false
    end

    belongs_to :tag, Timeclock.System.Tag do
      public? true
    end

    has_many :absences, Timeclock.Absences.Absence do
      public? true
      destination_attribute :absence_definition_id
    end
  end


  postgres do
    table "absence_definitions"
    repo Timeclock.Repo

    references do
      reference :code, on_delete: :restrict
      reference :tag, on_delete: :nilify
    end
  end

  oban do
    triggers do
      trigger :annual_accrual_rollover do
        action :run_annual_rollover
        where expr(active == true)
        scheduler_cron "5 0 1 1 *"
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
        :max_days_per_year,
        :fraction,
        :active,
        :available_for_admins_only,
        :description,
        :requires_approval,
        :icon,
        :code_id,
        :tag_id
      ]

      change run_reactor(Timeclock.Absences.Reactors.SetupDefinition)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :type,
        :max_days_per_year,
        :fraction,
        :active,
        :available_for_admins_only,
        :description,
        :requires_approval,
        :icon,
        :code_id,
        :tag_id
      ]
    end

    update :toggle_active do
      accept [:active]
    end

    update :run_annual_rollover do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Absences.Reactors.AnnualAccrualRollover)
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
      authorize_if expr(active == true and available_for_admins_only == false)
    end

    # Only admins can create, modify, or delete absence definitions
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
