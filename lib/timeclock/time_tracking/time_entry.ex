defmodule Timeclock.TimeTracking.TimeEntry do
  use Timex

  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.TimeTracking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :timestamp, :utc_datetime do
      public? true
    end

    attribute :direction, Timeclock.Types.Direction do
      public? true
    end

    attribute :geolocation, Timeclock.TimeTracking.Geolocation do
      public? true
    end
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "time_entries"
    repo Timeclock.Repo
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
    end

    belongs_to :task, Timeclock.Projects.Task do
      public? true
    end

    belongs_to :clocking, Timeclock.Clocking.Clocking do
      public? true
    end
  end

  validations do
    validate present([:timestamp]), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  preparations do
    prepare build(load: [:user, :task])
  end

  actions do
    defaults [:read]

    read :today do
      # Default sort - overridden if user provides any sort
      prepare build(default_sort: [timestamp: :desc])
      prepare load(:user)

      argument :actor, :map, allow_nil?: false

      # Always applied filter - cannot be overridden
      filter expr(timestamp >= Datetime.today() |> beginning_of_day())
      filter expr(user.id = arg.actor.id)

      # Default pagination
      pagination offset: true, default_limit: 20
    end
  end

  #  calculations do
  #    calculate :total_hours, :string, expr(first_name <> ^arg(:separator) <> last_name) do
  #      argument :separator, :string do
  #        allow_nil? false
  #        default " "
  #      end
  #    end
  #  end
end
