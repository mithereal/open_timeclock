defmodule Timeclock.Scheduling do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Scheduling.BreakRule

    resource Timeclock.Calendar.Calendar do
      define :init, action: :init
      define :set, action: :update
      define :get_by_id, action: :read, get_by: [:id]
    end

    resource Timeclock.Scheduling.Schedule
    resource Timeclock.Scheduling.Shift
    resource Timeclock.Calendar.Event
    resource Timeclock.Calendar.Group
  end
end
