defmodule Timeclock.Seed do
  defmacro __using__(_opts) do
    quote do
      use PhilColumns.Seed

      # shared code here ...
    end
  end
end
