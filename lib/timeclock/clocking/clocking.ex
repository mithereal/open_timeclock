defmodule Timeclock.Clocking.Clocking do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :punched_at, :utc_datetime do
      public? true
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :source, :atom do
      public? true
      allow_nil? false
      default :web
      constraints one_of: [:web, :kiosk, :mobile, :system, :lua_plugin]
    end

    attribute :comment, :string do
      public? true
      allow_nil? true
      constraints max_length: 1000, trim?: true
    end

    attribute :has_geo_location, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :latitude, :float do
      public? true
      allow_nil? true
      constraints min: -90.0, max: 90.0
    end

    attribute :longitude, :float do
      public? true
      allow_nil? true
      constraints min: -180.0, max: 180.0
    end

    attribute :flag_reason, :string do
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

    belongs_to :status, Timeclock.System.Status do
      public? true
      allow_nil? false
    end

    belongs_to :modified_by_user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :definition, Timeclock.Clocking.Definition do
      public? true
      allow_nil? false
    end

    belongs_to :interface_detail, Timeclock.Clocking.InterfaceDetail do
      public? true
    end

    belongs_to :approval_request, Timeclock.Approvals.Approval do
      public? true
    end

    has_many :entries, Timeclock.TimeTracking.TimeEntry do
      public? true
      destination_attribute :clocking_id
    end
  end

  postgres do
    table "clockings"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :delete
      reference :status, on_delete: :restrict
      reference :modified_by_user, on_delete: :nilify
      reference :definition, on_delete: :restrict
      reference :interface_detail, on_delete: :nilify
      reference :approval_request, on_delete: :nilify
    end

    custom_indexes do
      index [:user_id, :punched_at]
    end
  end

  workflow do
    queue :workflow

    step :recorded do
      action :process_punch
      on_success :verified
      on_error :flagged
    end

    step :verified do
      transition :flag, to: :flagged
      transition :void, to: :voided

      # Flag unclosed/unreconciled punches after 14 hours for manager review
      timeout after: {14, :hours}, action: :flag_stale_punch
    end

    step :flagged do
      transition :resolve_flag, to: :verified
      transition :void, to: :voided
    end

    step :voided
  end

  validations do
    validate present([:latitude, :longitude]),
      where: attribute_equals(:has_geo_location, true),
      on: [:insert_from_web, :insert_from_kiosk, :update],
      message: "latitude and longitude are required when has_geo_location is true"
  end

  actions do
    defaults [:read]

    create :insert_from_web do
      primary? true
      description "Insert a Clocking punch for the authenticated User from the web portal."

      accept [
        :comment,
        :has_geo_location,
        :latitude,
        :longitude,
        :status_id,
        :definition_id,
        :interface_detail_id
      ]

      # Server-enforced actor ownership and server timestamp to prevent client clock spoofing
      change relate_actor(:user)
      change set_attribute(:source, :web)
      change set_attribute(:punched_at, &DateTime.utc_now/0)
    end

    create :insert_from_kiosk do
      description "Insert a Clocking punch from a physical/shared Kiosk terminal."

      accept [
        :user_id,
        :comment,
        :has_geo_location,
        :latitude,
        :longitude,
        :status_id,
        :definition_id,
        :interface_detail_id
      ]

      change set_attribute(:source, :kiosk)
      change set_attribute(:punched_at, &DateTime.utc_now/0)
    end

    update :process_punch do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Clocking.Reactors.ProcessClockingPunch)
      change transition_state(:verified)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :punched_at,
        :comment,
        :status_id,
        :definition_id,
        :approval_request_id
      ]

      change relate_actor(:modified_by_user)
    end

    update :flag do
      accept [:flag_reason]
      require_atomic? false
      change transition_state(:flagged)
    end

    update :flag_stale_punch do
      accept []
      require_atomic? false
      change set_attribute(:flag_reason, "Punch exceeded 14-hour shift threshold")
      change transition_state(:flagged)
    end

    update :resolve_flag do
      accept []
      require_atomic? false
      change relate_actor(:modified_by_user)
      change set_attribute(:flag_reason, nil)
      change transition_state(:verified)
    end

    update :void do
      accept [:flag_reason]
      require_atomic? false
      change relate_actor(:modified_by_user)
      change transition_state(:voided)
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

    # Admins/managers read all punches; employees only read their own
    policy action_type(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Any authenticated employee can punch in/out for themselves via web
    policy action(:insert_from_web) do
      authorize_if always()
    end

    # Kiosk terminal accounts, managers, and admins can submit kiosk punches
    policy action(:insert_from_kiosk) do
      authorize_if expr(^actor(:role) in [:admin, :manager, :kiosk])
    end

    # Only managers and admins can edit, flag, resolve, or void punches
    policy action([:update, :flag, :resolve_flag, :void]) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
    end
  end
end
