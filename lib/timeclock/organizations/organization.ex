defmodule Timeclock.Organizations.Organization do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Organizations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 150, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    has_many :companies, Timeclock.Organizations.Company do
      public? true
      destination_attribute :organization_id
    end
  end

  postgres do
    table "organizations"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name]
      change run_reactor(Timeclock.Organizations.Reactors.SyncOrganization)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name]
      change run_reactor(Timeclock.Organizations.Reactors.SyncOrganization)
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

    # Authenticated users can read organization details
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete organizations
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
