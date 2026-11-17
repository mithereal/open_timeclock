defmodule Timeclock.Organizations.Department do
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
      constraints min_length: 2, max_length: 100, trim?: true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_company_department_name, [:company_id, :name]
  end

  relationships do
    belongs_to :company, Timeclock.Organizations.Company do
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
  end

  postgres do
    table "departments"
    repo Timeclock.Repo

    references do
      reference :company, on_delete: :restrict
      reference :starting_category_definition, on_delete: :nilify
      reference :absence_category_definition, on_delete: :nilify
      reference :in_clocking_definition, on_delete: :nilify
      reference :out_clocking_definition, on_delete: :nilify
    end
  end

  validations do
    validate fn changeset, _context ->
      in_id = Ash.Changeset.get_attribute(changeset, :in_clocking_definition_id)
      out_id = Ash.Changeset.get_attribute(changeset, :out_clocking_definition_id)

      if not is_nil(in_id) and in_id == out_id do
        {:error,
         field: :out_clocking_definition_id,
         message: "out clocking definition must differ from in clocking definition"}
      else
        :ok
      end
    end,
    on: [:create, :update]
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :name,
        :company_id,
        :starting_category_definition_id,
        :absence_category_definition_id,
        :in_clocking_definition_id,
        :out_clocking_definition_id
      ]

      change run_reactor(Timeclock.Organizations.Reactors.SyncDepartment)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :name,
        :company_id,
        :starting_category_definition_id,
        :absence_category_definition_id,
        :in_clocking_definition_id,
        :out_clocking_definition_id
      ]

      change run_reactor(Timeclock.Organizations.Reactors.SyncDepartment)
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

    # Authenticated users can read department details
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can create, modify, or delete departments
    policy action_type([:create, :update, :destroy]) do
      authorize_if expr(^actor(:role) == :admin)
    end
  end
end
