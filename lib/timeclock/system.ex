defmodule Timeclock.System do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.System.Address
    resource Timeclock.System.Card
    resource Timeclock.System.Category
    resource Timeclock.System.Icon
    resource Timeclock.System.Tag
    resource Timeclock.System.Code
    resource Timeclock.System.Status
    resource Timeclock.System.Type
  end
end
