defmodule Timeclock.Accounts.Account do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: [AshCommanded.Commanded.Dsl]

  postgres do
    table "accounts"
    repo Timeclock.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      public? true
      allow_nil? false
    end

    attribute :middle_name, :string do
      public? true
      allow_nil? false
    end

    attribute :last_name, :string do
      public? true
      allow_nil? false
    end

    attribute :full_name, :string do
      public? true
      allow_nil? false
    end

    attribute :birth_date, :date do
      public? true
      allow_nil? false
    end

    attribute :gender, :string do
      public? true
      allow_nil? false
    end

    attribute :address, :string do
      public? true
      allow_nil? false
    end

    attribute :city, :string do
      public? true
      allow_nil? false
    end

    attribute :state, :string do
      public? true
      allow_nil? false
    end

    attribute :phone, :string do
      public? true
      allow_nil? false
    end

    attribute :mobile, :string do
      public? true
      allow_nil? false
    end

    attribute :email, :string do
      public? true
      allow_nil? false
    end

    attribute :picture_uri, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_id, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field1, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field2, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field3, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field4, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field5, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field6, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field7, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field8, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field9, :string do
      public? true
      allow_nil? false
    end

    attribute :custom_field10, :string do
      public? true
      allow_nil? false
    end

    attribute :is_time_attendance_user, :boolean do
      public? true
      allow_nil? false
    end

    attribute :is_archived, :boolean do
      public? true
      allow_nil? false
    end

    attribute :has_user_account, :boolean do
      public? true
      allow_nil? false
    end

    attribute :has_assigned_pin, :boolean do
      public? true
      allow_nil? false
    end

    attribute :calculation_start_date, :date do
      public? true
      allow_nil? false
    end

    attribute :calculation_stop_date, :date do
      public? true
      allow_nil? false
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User
    has_many :logs, Timeclock.Audit.Log
  end
end
