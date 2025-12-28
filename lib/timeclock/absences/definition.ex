defmodule Timeclock.Absences.Definition do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :code, :string
    attribute :type, :string
    attribute :restriction_type, :string
    attribute :max_days_per_year, :integer
    attribute :fraction, :integer
    attribute :is_active, :boolean
    attribute :is_available_for_admins_only, :boolean

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_id, [:id]
  end

  relationships do
    belongs_to :tag, Timeclock.System.Tag
    belongs_to :integration, Timeclock.Absences.Integration
    belongs_to :icon, Timeclock.System.Icon
  end

  postgres do
    table "absence_definition"
    repo Timeclock.Repo
  end
end
