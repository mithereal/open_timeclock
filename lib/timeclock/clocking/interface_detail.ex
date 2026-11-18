defmodule Timeclock.Clocking.InterfaceDetail do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :button_index, :integer do
      public? true
      allow_nil? false
      constraints min: 0, max: 100
    end

    attribute :event_index, :integer do
      public? true
      allow_nil? false
      constraints min: 0, max: 100
    end

    attribute :is_default, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :icon, Timeclock.Types.Icon do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_button_slot, [:button_index, :event_index]
  end

  relationships do
    belongs_to :definition, Timeclock.Clocking.Definition do
      public? true
      allow_nil? false
    end

    belongs_to :tag, Timeclock.System.Tag do
      public? true
    end

    has_many :clockings, Timeclock.Clocking.Clocking do
      public? true
      destination_attribute :interface_detail_id
    end
  end

  postgres do
    table "clocking_interface_details"
    repo Timeclock.Repo

    references do
      reference :definition, on_delete: :delete
      reference :tag, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:button_index, :event_index, :is_default, :icon, :definition_id, :tag_id]
      change run_reactor(Timeclock.Clocking.Reactors.SyncInterfaceDetail)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:button_index, :event_index, :is_default, :icon, :definition_id, :tag_id]
      change run_reactor(Timeclock.Clocking.Reactors.SyncInterfaceDetail)
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

    # Authenticated employees and kiosk terminals can read button configurations
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete kiosk button layouts
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
