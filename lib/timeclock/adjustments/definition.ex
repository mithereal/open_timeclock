defmodule Timeclock.Adjustments.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Adjustments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :type, :integer do
      public? true
    end

    # Flags
    attribute :is_available_for_admins_only, :boolean do
      public? true
      default false
    end

    attribute :is_active, :boolean do
      public? true
      default true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "adjustment_definitions"
    repo Timeclock.Repo
  end

  relationships do
    has_many :adjustments, Timeclock.Adjustments.Adjustment

    belongs_to :account, Timeclock.Accounts.Account do
      public? true
    end

    belongs_to :code, Timeclock.System.Code do
      public? true
    end

    belongs_to :tag, Timeclock.System.Tag do
      public? true
    end

    validations do
      validate present([:name, :type]), on: [:create, :update]
      validate string_length(:name, min: 1, max: 255), on: [:create, :update]
    end

    actions do
      defaults [:read, :destroy, create: :*]
    end
  end

  preparations do
    prepare build(load: [:code, :tag, :account])
  end
end
