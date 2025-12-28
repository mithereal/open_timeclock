defmodule Timeclock.Clocking do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Clocking.Beacon
    resource Timeclock.Clocking.Clocking
    resource Timeclock.Clocking.Definition
    resource Timeclock.Clocking.Device
    resource Timeclock.Clocking.InterfaceDetail
    resource Timeclock.Clocking.Origin
    resource Timeclock.Clocking.Point
  end
end
