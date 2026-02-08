defmodule Timeclock.Types.Direction do
  @moduledoc false
  use Ash.Type.Enum, values: [:in, :out]
end
