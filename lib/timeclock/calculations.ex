defmodule Timeclock.Calculations do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Calculations.Calculation
    resource Timeclock.Calculations.CalculationCategory
    resource Timeclock.Calculations.CalculationDetail
  end
end
