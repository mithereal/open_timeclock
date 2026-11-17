defmodule Timeclock.Absences.Generator do
  use Ash.Generator

  @doc """
  Generates a valid `Timeclock.Absences.Absence` changeset through the `:create` action.
  Pass `actor: user` in `opts` when testing policy enforcement.
  """
  def absence(opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    default_end = DateTime.add(now, 8, :hour)

    absence_definition_id =
      opts[:absence_definition_id] ||
        once(:default_absence_definition_id, fn ->
          generate(definition(actor: opts[:actor])).id
        end)

    changeset_generator(
      Timeclock.Absences.Absence,
      :create,
      defaults: [
        start_date: now,
        end_date: default_end,
        reason: sequence(:absence_reason, &"Scheduled personal absence ##{&1}"),
        absence_definition_id: absence_definition_id
      ],
      overrides: opts
    )
  end

  @doc """
  Directly seeds a `Timeclock.Absences.Absence` record into Postgres,
  bypassing `:create` action rules (useful for testing historical or edge-case states).
  """
  def seed_absence(opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    default_end = DateTime.add(now, 8, :hour)

    seed_generator(
      %Timeclock.Absences.Absence{
        start_date: now,
        end_date: default_end,
        reason: sequence(:seed_absence_reason, &"Seeded absence ##{&1}")
      },
      overrides: opts
    )
  end

  @doc """
  Generates a valid `Timeclock.Absences.Definition` through the `:create` action,
  satisfying all numeric bounds, string length constraints, and required relationships.
  """
  def definition(opts \\ []) do
    changeset_generator(
      Timeclock.Absences.Definition,
      :create,
      defaults: [
        name: sequence(:definition_name, &"Leave Policy #{&1}"),
        type: "paid_time_off",
        max_days_per_year: 20,
        fraction: 100,
        active: true,
        available_for_admins_only: false,
        description:
          StreamData.repeatedly(fn ->
            Faker.Lorem.paragraph(2)
            |> String.slice(0, 500)
          end),
        requires_approval: true,
        icon: "hero-calendar-days"
      ],
      overrides: opts
    )
  end
end
