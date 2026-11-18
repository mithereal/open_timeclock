defmodule Timeclock.Calendar.Group do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Calendar,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  @valid_day_keys ~w(monday tuesday wednesday thursday friday saturday sunday)

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :workdays, :map do
      public? true
      allow_nil? false
      default %{
        "monday" => true,
        "tuesday" => true,
        "wednesday" => true,
        "thursday" => true,
        "friday" => true,
        "saturday" => false,
        "sunday" => false
      }
    end

    attribute :time_zone, :string do
      public? true
      allow_nil? false
      default "America/Phoenix"
      constraints min_length: 2, max_length: 100, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    has_many :events, Timeclock.Calendar.Event do
      public? true
      destination_attribute :group_id
    end
  end

  postgres do
    table "calendar_groups"
    repo Timeclock.Repo
  end

  validations do
    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :time_zone) do
        nil ->
          :ok

        tz ->
          case DateTime.shift_zone(DateTime.utc_now(), tz) do
            {:ok, _} -> :ok
            {:error, _} -> {:error, field: :time_zone, message: "must be a valid IANA timezone"}
          end
      end
    end,
    on: [:create, :update]

    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :workdays) do
        nil ->
          :ok

        workdays when is_map(workdays) and map_size(workdays) > 0 ->
          invalid_keys =
            workdays
            |> Map.keys()
            |> Enum.reject(&(to_string(&1) in @valid_day_keys))

          if invalid_keys == [] do
            :ok
          else
            {:error, field: :workdays, message: "contains invalid weekday keys"}
          end

        _ ->
          {:error, field: :workdays, message: "must be a non-empty map of weekday configurations"}
      end
    end,
    on: [:create, :update]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :workdays, :time_zone]
      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendarGroup)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :workdays, :time_zone]
      change run_reactor(Timeclock.Calendar.Reactors.SyncCalendarGroup)
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

    # Authenticated users can read calendar groups
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete calendar groups
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
