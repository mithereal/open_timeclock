defmodule Timeclock.Seed do
  defmacro __using__(_opts) do
    quote do
      use PhilColumns.Seed
      require Ash.Query
      # shared code here ...
    end
  end
end
