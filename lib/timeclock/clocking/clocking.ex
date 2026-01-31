defmodule Timeclock.Clocking.Clocking do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :timestamp, :utc_datetime do
      public? true
    end

    attribute :original_timestamp, :utc_datetime do
      public? true
    end

    attribute :is_authentic, :boolean do
      public? true
      default false
    end

    attribute :comment, :string do
      public? true
    end

    attribute :geo_location_timestamp, :utc_datetime do
      public? true
    end

    attribute :has_geo_location, :boolean do
      public? true
      default false
    end

    attribute :accuracy, :float do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "clockings"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :modified_by_user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :device, Timeclock.Clocking.Device do
      public? true
    end

    belongs_to :status, Timeclock.System.Status do
      public? true
    end

    belongs_to :beacon, Timeclock.Clocking.Beacon do
      public? true
    end

    belongs_to :point, Timeclock.Clocking.Point do
      public? true
    end

    belongs_to :definition, Timeclock.Clocking.Definition do
      public? true
    end

    belongs_to :interface_detail, Timeclock.Clocking.InterfaceDetail do
      public? true
    end

    belongs_to :origin, Timeclock.Clocking.Origin do
      public? true
    end

    belongs_to :original_clocking_definition, Timeclock.Clocking.Definition do
      public? true
    end

    belongs_to :approval_request, Timeclock.Approvals.Request do
      public? true
    end
  end

  validations do
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
