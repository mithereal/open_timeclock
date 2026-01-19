defmodule Timeclock.Checks.PasswordChangeInteraction do
  use Ash.Policy.SimpleCheck

  @impl Ash.Policy.Check
  def describe(_) do
    "Timeclock is performing a password change for this interaction"
  end

  @impl Ash.Policy.SimpleCheck
  def match?(_, %{subject: %{context: %{private: %{password_change?: true}}}}, _), do: true
  def match?(_, _, _), do: false
end
