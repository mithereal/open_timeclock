defmodule Timeclock.Audit do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Audit.Log
    resource Timeclock.Audit.LogType
    resource Timeclock.Calendar.EventType
  end
end
