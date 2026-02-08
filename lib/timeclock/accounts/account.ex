defmodule Timeclock.Accounts.Account do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [],
    extensions: []

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

    attribute :assigned_pin, :integer do
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
    belongs_to :user, Timeclock.Accounts.User do
      public? true
    end

    actions do
      defaults [:read]

      read :has_user_account do
        description "Checks of theres an assigned user."
        argument :id, :uuid, allow_nil?: false
      end

      read :has_assigned_pin do
        description "Checks of theres an assigned pin."
        argument :assigned_pin, :integer, allow_nil?: false
      end
    end

    code_interface do
      # the action open can be omitted because it matches the function name
      define :has_user_account, args: [:id]
      define :has_assigned_pin, args: [:assigned_pin]
    end

    calculations do
      calculate :full_name, :string, expr(first_name <> ^arg(:separator) <> last_name) do
        argument :separator, :string do
          allow_nil? false
          default " "
        end
      end
    end

    actions do
      defaults [:read, :destroy, create: :*]
    end

    preparations do
      prepare build(load: [:user])
    end
  end
end
