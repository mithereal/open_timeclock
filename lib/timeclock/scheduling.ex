defmodule Timeclock.Scheduling do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Scheduling.BreakRule
    resource Timeclock.Scheduling.Calendar
    resource Timeclock.Scheduling.Schedule
    resource Timeclock.Scheduling.Shift
  end
end
