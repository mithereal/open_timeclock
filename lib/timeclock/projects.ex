defmodule Timeclock.Projects do
  use Ash.Domain, otp_app: :timeclock, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Timeclock.Projects.Assignment
    resource Timeclock.Projects.Project
    resource Timeclock.Projects.Task
  end
end
