defmodule Timeclock.Organizations do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Organizations.Address
    resource Timeclock.Organizations.Company
    resource Timeclock.Organizations.Department
    resource Timeclock.Organizations.Organization
  end
end
