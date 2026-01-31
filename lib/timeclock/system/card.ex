defmodule Timeclock.System.Card do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.System,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id

    attribute :brand, :string do
      public? true
    end

    attribute :exp_month, :integer do
      public? true
    end

    attribute :exp_year, :integer do
      public? true
    end

    attribute :last4, :string do
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  postgres do
    table "cards"
    repo Timeclock.Repo
  end

  validations do
    validate present([:brand, :exp_month, :exp_year, :last4]), on: [:create, :update]
    validate compare(:exp_month, greater_than_or_equal_to: 1), on: [:create, :update]
    validate compare(:exp_month, less_than_or_equal_to: 12), on: [:create, :update]
    validate compare(:exp_year, greater_than: Date.utc_today().year), on: [:create, :update]
    validate string_length(:last4, min: 4, max: 4), on: [:create, :update]
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end
end
