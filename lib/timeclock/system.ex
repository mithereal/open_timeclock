defmodule Timeclock.System do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.System.Icon
    resource Timeclock.System.Tag
    resource Timeclock.System.Code
  end
end
