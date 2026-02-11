defmodule Timeclock.TimeTracking.Generator do
  use Ash.Generator

  def time_tracking(opts \\ []) do
    changeset_generator(
      Timeclock.TimeTracking.TimeEntry,
      :create,
      defaults: [
        user_id: opts[:user_id],
        direction: :in,
        timestamp: Timex.now()
      ],
      overrides: opts
    )
  end
end
