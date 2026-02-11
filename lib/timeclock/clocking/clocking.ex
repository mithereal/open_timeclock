defmodule Timeclock.Clocking.Clocking do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  actions do
    defaults [:read]

    create :insert_from_web do
      description "Insert a Clocking for a User."

      argument :user, :map do
        allow_nil? false
      end

      argument :timestamp, :utc_datetime do
        allow_nil? false
      end

      argument :status, :map do
        allow_nil? false
      end

      argument :definition, :string do
        allow_nil? false
      end

      change set_attribute(:user, arg(:user))
      change set_attribute(:status, arg(:status))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :comment, :string do
      public? true
    end

    attribute :has_geo_location, :boolean do
      public? true
      default false
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

    belongs_to :status, Timeclock.System.Status do
      public? true
    end

    belongs_to :modified_by_user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :definition, Timeclock.Clocking.Definition do
      public? true
    end

    belongs_to :interface_detail, Timeclock.Clocking.InterfaceDetail do
      public? true
    end

    belongs_to :approval_request, Timeclock.Approvals.Approval do
      public? true
    end

    has_many :entries, Timeclock.TimeTracking.TimeEntry
  end

  preparations do
    prepare build(load: [:definition, :status, :interface_detail])
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
