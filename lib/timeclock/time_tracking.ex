defmodule Timeclock.TimeTracking do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.TimeTracking.TimeEntry do
      define :today, args: [:email], action: :today
    end
  end
end
