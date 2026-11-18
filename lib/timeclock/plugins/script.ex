defmodule Timeclock.Plugins.Script do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Plugins,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  @allowed_hooks ~w(
    punch.before_verify
    time_entry.after_record
    geolocation.validate
    absence.after_approve
    adjustment.periodic
    approval.after_approve
    delegation.updated
    shift.differential
    break.compliance
    schedule.synced
    payroll.code_sync
    security.token_revoked
  )

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true, match: ~r/^[a-z0-9_\-]+$/
    end

    attribute :description, :string do
      public? true
      allow_nil? true
      constraints max_length: 500, trim?: true
    end

    attribute :hook_event, :string do
      public? true
      allow_nil? false
      constraints min_length: 3, max_length: 80, trim?: true
    end

    attribute :source_code, :string do
      public? true
      allow_nil? false
      constraints min_length: 5, max_length: 65_536
    end

    attribute :priority, :integer do
      public? true
      allow_nil? false
      default 100
      constraints min: 1, max: 10_000
    end

    attribute :is_active, :boolean do
      public? true
      allow_nil? false
      default true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_script_name, [:name]
  end

  postgres do
    table "lua_scripts"
    repo Timeclock.Repo

    custom_indexes do
      index [:hook_event, :is_active, :priority]
    end
  end

  validations do
    validate one_of(:hook_event, @allowed_hooks),
      on: [:create, :update],
      message: "must be a supported Timeclock hook event"

    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :source_code) do
        code when is_binary(code) ->
          case Timeclock.Plugins.LuaRunner.validate_syntax(code) do
            :ok -> :ok
            {:error, msg} -> {:error, field: :source_code, message: "Lua syntax error: #{msg}"}
          end

        _ ->
          :ok
      end
    end,
    on: [:create, :update]
  end

  actions do
    defaults [:read]

    read :active_for_hook do
      argument :hook_event, :string, allow_nil?: false
      filter expr(hook_event == ^arg(:hook_event) and is_active == true)
      prepare build(sort: [priority: :asc])
    end

    create :create do
      primary? true
      accept [:name, :description, :hook_event, :source_code, :priority, :is_active]
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :description, :hook_event, :source_code, :priority, :is_active]
    end

    update :toggle_active do
      accept [:is_active]
    end

    destroy :destroy do
      primary? true
    end
  end

  code_interface do
    define :active_for_hook, args: [:hook_event]
  end

  policies do
    # Internal LuaRunner dispatch runs without a user actor when loading active hooks
    bypass action(:active_for_hook) do
      authorize_if always()
    end

    # Block all anonymous access on user-facing actions
    bypass always() do
      forbid_unless actor_present()
    end

    # Only admins can view, upload, edit, toggle, or delete Lua plugins
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
