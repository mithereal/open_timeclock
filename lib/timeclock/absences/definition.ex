defmodule Timeclock.Absences.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Absences,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :type, :string do
      public? true
      allow_nil? false
    end

    attribute :max_days_per_year, :integer do
      public? true
      allow_nil? false
    end

    attribute :fraction, :integer do
      public? true
      allow_nil? false
    end

    attribute :active, :boolean do
      public? true
      allow_nil? false
    end

    attribute :available_for_admins_only, :boolean do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
      allow_nil? false
    end

    attribute :requires_approval, :boolean do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :code, Timeclock.System.Code do
      public? true
    end

    belongs_to :tag, Timeclock.System.Tag do
      public? true
    end

    belongs_to :icon, Timeclock.System.Icon do
      public? true
    end
  end

  postgres do
    table "absence_definitions"
    repo Timeclock.Repo
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  preparations do
    prepare build(load: [:code, :tag, :icon])
  end
end
