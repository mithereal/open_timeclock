defmodule Timeclock.Organizations.Company do
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

    attribute :address, Timeclock.Types.Address do
      public? true
      allow_nil? true
    end

    attribute :registration_number, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 50, trim?: true, match: ~r/^[A-Za-z0-9\-]+$/
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_registration_number, [:registration_number]
    identity :unique_org_company_name, [:organization_id, :name]
  end

  relationships do
    belongs_to :organization, Timeclock.Organizations.Organization do
      public? true
      allow_nil? false
    end
  end

  postgres do
    table "companies"
    repo Timeclock.Repo

    references do
      reference :organization, on_delete: :restrict
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :address, :registration_number, :organization_id]
      change run_reactor(Timeclock.Organizations.Reactors.SyncCompany)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :address, :registration_number, :organization_id]
      change run_reactor(Timeclock.Organizations.Reactors.SyncCompany)
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

    # Authenticated users can read company details
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete companies
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
