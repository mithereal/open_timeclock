defmodule Timeclock.Adjustments do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Adjustments.Adjustment
    resource Timeclock.Adjustments.Definition
  end
end
