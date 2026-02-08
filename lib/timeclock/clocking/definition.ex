defmodule Timeclock.Clocking.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Clocking,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
    end

    attribute :type, Timeclock.Types.Definition do
      public? true
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    attribute :restriction_type, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "clocking_definition"
    repo Timeclock.Repo
  end

  relationships do
    has_one :clocking, Timeclock.Clocking.Clocking

    belongs_to :code, Timeclock.System.Code do
      public? true
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

  validations do
    validate present(:name), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  preparations do
    prepare build(load: [:code])
  end
end
