defmodule Timeclock.Accounts.Account do
  use Ash.Resource,
    otp_app: :timeclock,
    domain: Timeclock.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshWorkflow, AshOban]

  attributes do
    uuid_primary_key :id

    attribute :first_name, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 100, trim?: true
    end

    attribute :middle_name, :string do
      public? true
      allow_nil? true
      constraints max_length: 100, trim?: true
    end

    attribute :last_name, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 100, trim?: true
    end

    attribute :birth_date, :date do
      public? true
      allow_nil? false
    end

    attribute :gender, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 30, trim?: true
    end

    attribute :address, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 255, trim?: true
    end

    attribute :city, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :state, :string do
      public? true
      allow_nil? false
      constraints min_length: 2, max_length: 100, trim?: true
    end

    attribute :phone, :string do
      public? true
      allow_nil? true
      constraints max_length: 30, trim?: true, match: ~r/^[0-9\+\-\(\)\s\.]+$/
    end

    attribute :mobile, :string do
      public? true
      allow_nil? false
      constraints min_length: 7, max_length: 30, trim?: true, match: ~r/^[0-9\+\-\(\)\s\.]+$/
    end

    attribute :email, :string do
      public? true
      allow_nil? false
      constraints min_length: 5,
                  max_length: 254,
                  trim?: true,
                  match: ~r/^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/
    end

    attribute :picture_uri, :string do
      public? true
      allow_nil? true
      constraints max_length: 500, trim?: true
    end

    attribute :custom_id, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 50, trim?: true, match: ~r/^[A-Za-z0-9_\-]+$/
    end

    attribute :custom_field1, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field2, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field3, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field4, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field5, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field6, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field7, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field8, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field9, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]
    attribute :custom_field10, :string, public?: true, allow_nil?: true, constraints: [max_length: 255]

    attribute :is_time_attendance_user, :boolean do
      public? true
      allow_nil? false
      default true
    end

    attribute :is_archived, :boolean do
      public? true
      allow_nil? false
      default false
    end

    attribute :assigned_pin, :integer do
      public? false
      sensitive? true
      allow_nil? false
      constraints min: 1000, max: 999_999
    end

    attribute :calculation_start_date, :date do
      public? true
      allow_nil? false
      default &Date.utc_today/0
    end

    attribute :calculation_stop_date, :date do
      public? true
      allow_nil? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_custom_id, [:custom_id]
    identity :unique_assigned_pin, [:assigned_pin]
    identity :unique_user, [:user_id]
  end

  relationships do
    belongs_to :user, Timeclock.Accounts.User do
      public? true
      allow_nil? true
    end
  end

  postgres do
    table "accounts"
    repo Timeclock.Repo

    references do
      reference :user, on_delete: :nilify
    end
  end

  workflow do
    queue :workflow

    step :onboarding do
      action :activate
      on_success :active
    end

    step :active do
      transition :suspend, to: :suspended
      transition :archive, to: :archived
    end

    step :suspended do
      transition :reactivate, to: :active
      transition :archive, to: :archived
    end

    step :archived
  end

  oban do
    triggers do
      # Automatically archives active accounts once their calculation_stop_date has passed
      trigger :archive_terminated_accounts do
        action :archive
        where expr(state == :active and not is_nil(calculation_stop_date) and calculation_stop_date < today())
        scheduler_cron "30 0 * * *"
        worker_read_action :read
      end
    end
  end

  validations do
    validate compare(:calculation_stop_date, greater_than_or_equal_to: :calculation_start_date),
      where: present(:calculation_stop_date),
      on: [:create, :update],
      message: "must be on or after calculation_start_date"
  end

  actions do
    defaults [:read]

    read :has_user_account do
      description "Fetches the account assigned to a given user ID."
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:id) and is_archived == false)
    end

    read :has_assigned_pin do
      description "Fetches an active time-attendance account by kiosk PIN."
      get? true
      argument :assigned_pin, :integer, allow_nil?: false

      filter expr(
               assigned_pin == ^arg(:assigned_pin) and is_time_attendance_user == true and
                 is_archived == false
             )
    end

    create :create do
      primary? true

      accept [
        :first_name,
        :middle_name,
        :last_name,
        :birth_date,
        :gender,
        :address,
        :city,
        :state,
        :phone,
        :mobile,
        :email,
        :picture_uri,
        :custom_id,
        :custom_field1,
        :custom_field2,
        :custom_field3,
        :custom_field4,
        :custom_field5,
        :custom_field6,
        :custom_field7,
        :custom_field8,
        :custom_field9,
        :custom_field10,
        :is_time_attendance_user,
        :assigned_pin,
        :calculation_start_date,
        :calculation_stop_date,
        :user_id
      ]

      change set_attribute(:is_archived, false)
    end

    update :activate do
      accept []
      require_atomic? false
      change run_reactor(Timeclock.Accounts.Reactors.SyncAccount)
      change transition_state(:active)
    end

    update :update do
      primary? true
      require_atomic? false

      accept [
        :first_name,
        :middle_name,
        :last_name,
        :birth_date,
        :gender,
        :address,
        :city,
        :state,
        :phone,
        :mobile,
        :email,
        :picture_uri,
        :custom_id,
        :custom_field1,
        :custom_field2,
        :custom_field3,
        :custom_field4,
        :custom_field5,
        :custom_field6,
        :custom_field7,
        :custom_field8,
        :custom_field9,
        :custom_field10,
        :is_time_attendance_user,
        :assigned_pin,
        :calculation_start_date,
        :calculation_stop_date,
        :user_id
      ]

      change run_reactor(Timeclock.Accounts.Reactors.SyncAccount)
    end

    update :update_self do
      description "Allows an employee to update their own contact details."
      require_atomic? false
      accept [:address, :city, :state, :phone, :mobile, :picture_uri]
    end

    update :suspend do
      accept []
      require_atomic? false
      change set_attribute(:is_time_attendance_user, false)
      change transition_state(:suspended)
      change run_reactor(Timeclock.Accounts.Reactors.SyncAccount)
    end

    update :reactivate do
      accept []
      require_atomic? false
      change set_attribute(:is_time_attendance_user, true)
      change set_attribute(:is_archived, false)
      change transition_state(:active)
      change run_reactor(Timeclock.Accounts.Reactors.SyncAccount)
    end

    update :archive do
      accept []
      require_atomic? false
      change set_attribute(:is_archived, true)
      change set_attribute(:is_time_attendance_user, false)
      change transition_state(:archived)
      change run_reactor(Timeclock.Accounts.Reactors.SyncAccount)
    end

    destroy :destroy do
      primary? true
    end
  end

  code_interface do
    define :has_user_account, args: [:id]
    define :has_assigned_pin, args: [:assigned_pin]
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> ^arg(:separator) <> last_name) do
      public? true

      argument :separator, :string do
        allow_nil? false
        default " "
      end
    end
  end

  policies do
    # Allow internal AshOban lifecycle triggers
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    # Block all anonymous access
    bypass always() do
      forbid_unless actor_present()
    end

    # Admins/managers read all accounts; employees only read their own account
    policy action(:read) do
      authorize_if expr(^actor(:role) in [:admin, :manager])
      authorize_if expr(user_id == ^actor(:id))
    end

    # Kiosk terminals, managers, and admins can resolve kiosk PINs and user linkage
    policy action([:has_user_account, :has_assigned_pin]) do
authorize_if expr(^actor(:role) in [:admin, :manager, :kiosk])
authorize_if expr(user_id == ^actor(:id))
end
# Employees can update their own contact details
policy action(:update_self) do
authorize_if expr(user_id == ^actor(:id) and is_archived == false)
end
# Only admins can create, fully edit, suspend, reactivate, archive, or delete accounts
policy action([:create, :update, :suspend, :reactivate, :archive, :destroy]) do
authorize_if expr(^actor(:role) == :admin)
end
end
end