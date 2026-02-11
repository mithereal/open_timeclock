defmodule Timeclock.Absences.Generator do
  use Ash.Generator

  def absence(opts \\ []) do
    seed_generator(
      %Timeclock.Absences.Absence{
        start_date: Timex.now(),
        end_date: Timex.now(),
        reason: sequence(:title, &"Absence #{&1}")
      },
      overrides: opts
    )
  end

  def definition(opts \\ []) do
    changeset_generator(
      Timeclock.Absences.Definition,
      :create,
      defaults: [
        name: sequence(:title, &"Definition #{&1}"),
        description: StreamData.repeatedly(fn -> Faker.Lorem.paragraph() end),
        active: true
      ],
      overrides: opts
    )
  end
end
