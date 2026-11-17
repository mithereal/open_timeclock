defmodule Timeclock.System.Code do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :code, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 50, trim?: true, match: ~r/^[A-Z0-9_\-]+$/
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_code, [:code]
  end

  relationships do
    has_many :absence_definitions, Timeclock.Absences.Definition do
      public? true
      destination_attribute :code_id
    end

    has_many :adjustment_definitions, Timeclock.Adjustments.Definition do
      public? true
      destination_attribute :code_id
    end

    has_many :clocking_definitions, Timeclock.Clocking.Definition do
      public? true
      destination_attribute :code_id
    end

    has_many :statuses, Timeclock.System.Status do
      public? true
      destination_attribute :code_id
    end
  end

  end

  postgres do
    table "codes"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:code]
    end

    update :update do
      primary? true
      accept [:code]
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

    # Authenticated users can read system/payroll codes
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete codes
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
