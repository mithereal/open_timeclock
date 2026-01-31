defmodule Timeclock.Absences do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Absences.Absence
    resource Timeclock.Absences.Definition
    resource Timeclock.System.Code
    resource Timeclock.System.Status
  end
end
