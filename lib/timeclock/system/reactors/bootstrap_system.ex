defmodule Timeclock.System.Reactors.BootstrapSystem do
  use Ash.Reactor
  require Logger

  input :actor

  step :ensure_settings_singleton do
    argument :actor, input(:actor)

    run fn %{actor: actor}, _context ->
      case Ash.read(Timeclock.System.Settings, actor: actor) do
        {:ok, []} ->
          Timeclock.System.Settings
          |> Ash.Changeset.for_create(:init, %{}, actor: actor)
          |> Ash.create()

        {:ok, [existing | _]} ->
          {:ok, existing}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  step :ensure_default_calendar do
    argument :actor, input(:actor)

    run fn %{actor: actor}, _context ->
      case Ash.read(Timeclock.Calendar.Calendar, actor: actor) do
        {:ok, []} ->
          Timeclock.Calendar.Calendar
          |> Ash.Changeset.for_create(:init, %{}, actor: actor)
          |> Ash.create()

        {:ok, [existing | _]} ->
          {:ok, existing}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  step :ensure_default_codes_and_statuses do
    argument :actor, input(:actor)
    wait_for [:ensure_settings_singleton, :ensure_default_calendar]

    run fn %{actor: actor}, _context ->
      with {:ok, reg_code} <- upsert_code("REG", actor),
           {:ok, sick_code} <- upsert_code("SICK", actor),
           {:ok, _present} <-
             upsert_status(
               %{
                 name: "Present / On-Duty",
                 presence_status: "present",
                 paid_time_status: "paid",
                 color: "#10B981",
                 icon: "hero-check-circle",
                 code_id: reg_code.id
               },
               actor
             ),
           {:ok, _absent} <-
             upsert_status(
               %{
                 name: "Absent / Sick Leave",
                 presence_status: "absent",
                 paid_time_status: "paid",
                 color: "#F43F5E",
                 icon: "hero-x-circle",
                 code_id: sick_code.id
               },
               actor
             ) do
        {:ok, :seeded}
      end
    end
  end

  step :run_application_setup_hook do
    argument :seeded, result(:ensure_default_codes_and_statuses)

    run fn _args, _context ->
      if Code.ensure_loaded?(Timeclock.System.Setup) and
           function_exported?(Timeclock.System.Setup, :run, 1) do
        {:ok, Timeclock.System.Setup.run(%{"bootstrapped_at" => DateTime.utc_now()})}
      else
        Logger.info("Timeclock.System.Setup.run/1 not defined; skipping custom setup hook.")
        {:ok, :skipped}
      end
    end
  end

  return :run_application_setup_hook

  defp upsert_code(code_str, actor) do
    require Ash.Query

    case Timeclock.System.Code
         |> Ash.Query.filter(code == ^code_str)
         |> Ash.read_one(actor: actor) do
      {:ok, nil} ->
        Timeclock.System.Code
        |> Ash.Changeset.for_create(:create, %{code: code_str}, actor: actor)
        |> Ash.create()

      {:ok, existing} ->
        {:ok, existing}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upsert_status(attrs, actor) do
    require Ash.Query

    case Timeclock.System.Status
         |> Ash.Query.filter(name == ^attrs.name)
         |> Ash.read_one(actor: actor) do
      {:ok, nil} ->
        Timeclock.System.Status
        |> Ash.Changeset.for_create(:create, attrs, actor: actor)
        |> Ash.create()

      {:ok, existing} ->
        {:ok, existing}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
