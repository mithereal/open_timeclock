defmodule Timeclock.Calendar.Calendar do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calendar,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  @valid_days ~w(monday tuesday wednesday thursday friday saturday sunday)

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      default "Default"
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :timezone, :string do
      public? true
      allow_nil? false
      default "America/Phoenix"
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :work_days, {:array, :string} do
      public? true
      allow_nil? false
      default ["monday", "tuesday", "wednesday", "thursday", "friday"]
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  postgres do
    table "calendars"
    repo Timeclock.Repo
  end

  validations do
    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :timezone) do
        nil ->
          :ok

        tz ->
          case DateTime.shift_zone(DateTime.utc_now(), tz) do
            {:ok, _} -> :ok
            {:error, _} -> {:error, field: :timezone, message: "must be a valid IANA timezone"}
          end
      end
    end,
    on: [:create, :update]

    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :work_days) do
        nil ->
          :ok

        [] ->
          {:error, field: :work_days, message: "must contain at least one work day"}

        days when is_list(days) ->
          cond do
            length(days) != length(Enum.uniq(days)) ->
              {:error, field: :work_days, message: "cannot contain duplicate days"}

            not Enum.all?(days, &(&1 in @valid_days)) ->
              {:error, field: :work_days, message: "contains an invalid day name"}

            true ->
              :ok
          end

        _ ->
          {:error, field: :work_days, message: "must be a list of weekday names"}
      end
    end,
    on: [:create, :update]
  end

  actions do
    defaults [:read]

    read :get do
      get? true
      filter expr(name == "Default")
    end

    # Safe one-time bootstrap action: only succeeds when no calendars exist yet
    create :init do
      accept []

      validate fn _changeset, _context ->
        case Ash.count(Timeclock.Calendar.Calendar, authorize?: false) do
          {:ok, 0} -> :ok
          _ -> {:error, field: :name, message: "default calendar is already initialized"}
        end
      end
    end

    create :create do
      primary? true
      accept [:name, :timezone, :work_days]
      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendar)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :timezone, :work_days]
      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendar)
    end

    destroy :destroy do
      primary? true
    end
  end

  policies do
    # Allow one-time bootstrap initialization
    policy action(:init) do
      authorize_if always()
    end

    # Block anonymous access on all other actions
    bypass always() do
      forbid_unless actor_present()
    end

    # Authenticated users can read calendars
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, update, or delete calendars
    policy action([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
