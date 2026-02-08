defmodule Timeclock.Calendar do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Calendar.Calendar
    resource Timeclock.Calendar.Event
    resource Timeclock.Calendar.Group
  end
end
