defmodule Timeclock.Clocking do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Clocking.Clocking
    resource Timeclock.Clocking.Definition
    resource Timeclock.Clocking.InterfaceDetail
    resource Timeclock.System.Code
  end
end
