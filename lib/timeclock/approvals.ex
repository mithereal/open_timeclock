defmodule Timeclock.Approvals do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Approvals.Approval
    resource Timeclock.Approvals.Definition
    resource Timeclock.Approvals.PermissionDelegation
    resource Timeclock.Approvals.AdditionalData
  end
end
