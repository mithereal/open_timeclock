defmodule Timeclock.Cldr do
  @moduledoc false
  use Cldr,
    otp_app: :timeclock,
    locales: ["en"],
    default_locale: "en",
    json_library: Jason,
    providers: [Cldr.Number],
    precompile_number_formats: ["¤¤#,##0.##"]

  def format_integer(number) when is_number(number) do
    number
    |> round()
    |> __MODULE__.Number.to_string!()
  end

  def format_float(number, params \\ 2) when is_number(number) do
    rounded = round(number)

    normalized =
      if rounded == number do
        rounded
      else
        Float.round(number, params)
      end

    __MODULE__.Number.to_string!(normalized)
  end
end
