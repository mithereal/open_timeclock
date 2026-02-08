defmodule Timeclock.Repo.Seeds.AddSystemStatus do
  use Timeclock.Seed

  envs([:dev])
  @params [{"Arrive", "green"}, {"Work From Home", "blue"}, {"Leave", "red"}]

  def insert(name, color) do
    Ash.Seed.seed!(Timeclock.System.Status, %{
      name: name,
      color: color
    })
  end

  def up(_repo) do
    Enum.each(@params, fn {name, color} -> __MODULE__.insert(name, color) end)
  end
end
