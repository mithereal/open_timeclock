defmodule Timeclock.Plugins do
  use Ash.Domain

  resources do
    resource Timeclock.Plugins.Script
  end
end
