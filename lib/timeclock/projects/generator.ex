defmodule Timeclock.Projects.Generator do
  use Ash.Generator

  def project(opts \\ []) do
    seed_generator(
      %Timeclock.Projects.Project{
        start_date: DateTime.now(),
        end_date: DateTime.now(),
        name: sequence(:title, &"Project #{&1}")
      },
      overrides: opts
    )
  end

  def task(opts \\ []) do
    changeset_generator(
      Timeclock.Projects.Task,
      :create,
      defaults: [
        description: StreamData.repeatedly(fn -> Faker.Lorem.paragraph() end),
        due_date: DateTime.now(),
        name: sequence(:title, &"Task #{&1}")
      ],
      overrides: opts
    )
  end
end
