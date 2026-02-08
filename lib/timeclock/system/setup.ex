defmodule Timeclock.System.Setup do
  defp apply_smtp_from_settings do
    case Timeclock.System.get_settings() do
      {:ok, settings} -> Timeclock.Mailer.apply_settings(settings)
      _ -> :ok
    end
  end

  def run(params) do
    apply_smtp_from_settings()
    params
  end
end
