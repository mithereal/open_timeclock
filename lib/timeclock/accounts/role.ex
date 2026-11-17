defmodule Timeclock.Accounts.Role do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  @protected_roles ~w(admin manager employee kiosk)
  @permission_regex ~r/^[a-z_]+:[a-z_*]+$/

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 50, trim?: true, match: ~r/^[a-z][a-z0-9_]*$/
    end

    attribute :permissions, {:array, :string} do
      public? true
      allow_nil? false
      default []
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? true
    end
  end

  postgres do
    table "roles"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :nilify
    end
  end

  validations do
    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :permissions) do
        nil ->
          :ok

        perms when is_list(perms) ->
          cond do
            length(perms) != length(Enum.uniq(perms)) ->
              {:error, field: :permissions, message: "cannot contain duplicate permissions"}

            not Enum.all?(perms, &(is_binary(&1) and Regex.match?(@permission_regex, &1))) ->
              {:error,
               field: :permissions,
               message: "each permission must follow 'domain:action' lowercase format"}

            true ->
              :ok
          end

        _ ->
          {:error, field: :permissions, message: "must be a list of permission strings"}
      end
    end,
    on: [:create, :update]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :permissions, :user_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncRole)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :permissions, :user_id]
      change run_reactor(Timeclock.Accounts.Reactors.SyncRole)
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      validate fn changeset, _context ->
        if changeset.data.name in @protected_roles do
          {:error, field: :name, message: "cannot delete protected system role"}
        else
          :ok
        end
      end
    end
  end

  policies do
    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Authenticated users can read role definitions for UI/session checks
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete roles
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
