defmodule Timeclock.Approvals do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Approvals.Request
    resource Timeclock.Approvals.RequestDefinition
    resource Timeclock.Approvals.PermissionDelegation
    resource Timeclock.Approvals.RequestAdditionalData
    resource Timeclock.Approvals.RequestLog
  end
end
