defmodule Timeclock.Analytics do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Analytics.Activity
    resource Timeclock.Analytics.AggregateFunction
  end
end
