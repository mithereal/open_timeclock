defmodule Timeclock.Accounts do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Accounts.Token
    resource Timeclock.Accounts.User
    resource Timeclock.Accounts.Account
    resource Timeclock.Accounts.Employee
    resource Timeclock.Accounts.Manager
    resource Timeclock.Accounts.Role
  end
end
