defmodule Timeclock.Clocking.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :type, :integer do
      public? true
      allow_nil? false
      constraints min: 0, max: 50
    end

    attribute :is_active, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :restriction_type, :string do
      public? true
      allow_nil? false
      default "none"
      constraints min_length: 2, max_length: 50, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name]
  end

  relationships do
    has_many :clockings, Timeclock.Clocking.Clocking do
      public? true
      destination_attribute :definition_id
    end

    belongs_to :code, Timeclock.System.Code do
      public? true
      allow_nil? false
    end

    belongs_to :starting_category_definition, Timeclock.System.Status do
      public? true
    end

    belongs_to :absence_category_definition, Timeclock.System.Status do
      public? true
    end

    belongs_to :in_clocking_definition, Timeclock.Clocking.Definition do
      public? true
    end

    belongs_to :out_clocking_definition, Timeclock.Clocking.Definition do
      public? true
    end

    belongs_to :tag, Timeclock.System.Tag do
      public? true
    end
  end

  postgres do
    table "clocking_definition"
    repo Timeclock.Repo

    references do
      reference :code, on_delete: :restrict
      reference :starting_category_definition, on_delete: :nilify
      reference :absence_category_definition, on_delete: :nilify
      reference :in_clocking_definition, on_delete: :nilify
      reference :out_clocking_definition, on_delete: :nilify
      reference :tag, on_delete: :nilify
    end
  end

  validations do
    validate one_of(:restriction_type, [
               "none",
               "web_only",
               "kiosk_only",
               "geofence_required",
               "admin_only"
             ]),
             on: [:create, :update]

    validate fn changeset, _context ->
      id = Ash.Changeset.get_attribute(changeset, :id)
      in_id = Ash.Changeset.get_attribute(changeset, :in_clocking_definition_id)
      out_id = Ash.Changeset.get_attribute(changeset, :out_clocking_definition_id)

      cond do
        not is_nil(id) and id == in_id ->
          {:error, field: :in_clocking_definition_id, message: "cannot reference itself"}

        not is_nil(id) and id == out_id ->
          {:error, field: :out_clocking_definition_id, message: "cannot reference itself"}

        true ->
          :ok
      end
    end,
    on: [:update]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :type,
        :is_active,
        :restriction_type,
        :code_id,
        :starting_category_definition_id,
        :absence_category_definition_id,
        :in_clocking_definition_id,
        :out_clocking_definition_id,
        :tag_id
      ]

      change run_reactor(Timeclock.Clocking.Reactors.SyncClockingDefinition)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :type,
        :is_active,
        :restriction_type,
        :code_id,
        :starting_category_definition_id,
        :absence_category_definition_id,
        :in_clocking_definition_id,
        :out_clocking_definition_id,
        :tag_id
      ]

      change run_reactor(Timeclock.Clocking.Reactors.SyncClockingDefinition)
    end

    update :toggle_active do
      accept [:is_active]
      change run_reactor(Timeclock.Clocking.Reactors.SyncClockingDefinition)
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

    # Admins see all definitions; employees and kiosks only see active definitions
    policy action_type(:read) do
      authorize_if expr(^actor(:role) == :admin)
      authorize_if expr(is_active == true)
    end

    # Only admins can create, modify, or delete clocking definitions
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
