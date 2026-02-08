defmodule Timeclock.System do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.System.Address
    resource Timeclock.System.Icon
    resource Timeclock.System.Tag
    resource Timeclock.System.Code
    resource Timeclock.System.Status
    resource Timeclock.System.Type

    resource Timeclock.System.Settings do
      define :init, action: :init
      define :set, action: :update
      define :get_settings, action: :get
      define :get_by_id, action: :read, get_by: [:id]
    end
  end
end
