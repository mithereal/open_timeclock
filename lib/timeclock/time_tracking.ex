defmodule Timeclock.TimeTracking do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.TimeTracking.Geolocation
    resource Timeclock.TimeTracking.TimeEntry
  end
end
