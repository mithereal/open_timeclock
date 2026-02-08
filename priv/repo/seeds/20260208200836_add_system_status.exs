defmodule Timeclock.Repo.Seeds.AddSystemStatus do
  use Timeclock.Seed

  envs([:dev])
  @status [{"Arrive", "green"}, {"Work From Home", "blue"}, {"Leave", "red"}]

  def insert(name, color) do
      Timeclock.System.Status
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        color: color
      })
      |> Ash.create()
  end

  def up(_repo) do
    Enum.each(@status, fn {name, color} -> __MODULE__.insert(name, color) end)
  end
end
