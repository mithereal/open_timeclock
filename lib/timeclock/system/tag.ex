defmodule Timeclock.System.Tag do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 50, trim?: true, match: ~r/^[A-Za-z0-9\s_\-]+$/
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    has_many :absence_definitions, Timeclock.Absences.Definition do
      public? true
      destination_attribute :tag_id
    end

    has_many :adjustment_definitions, Timeclock.Adjustments.Definition do
      public? true
      destination_attribute :tag_id
    end

    has_many :clocking_definitions, Timeclock.Clocking.Definition do
      public? true
      destination_attribute :tag_id
    end

    has_many :clocking_interface_details, Timeclock.Clocking.InterfaceDetail do
      public? true
      destination_attribute :tag_id
    end
  end

  postgres do
    table "tags"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name]
      change run_reactor(Timeclock.System.Reactors.SyncTag)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name]
      change run_reactor(Timeclock.System.Reactors.SyncTag)
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

    # Authenticated users can read system tags
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete tags
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
