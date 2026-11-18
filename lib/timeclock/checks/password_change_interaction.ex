defmodule Timeclock.Checks.PasswordChangeInteraction do
  @moduledoc """
  Policy check that authorizes an interaction only when `context.private.password_change?`
  is explicitly set to `true` server-side.
  """
  use Ash.Policy.SimpleCheck

  @impl Ash.Policy.Check
  def describe(_options) do
    "Timeclock is performing an authorized password change interaction"
  end

  @impl Ash.Policy.SimpleCheck
  def match?(_actor, %{subject: %Ash.Changeset{context: %{private: %{password_change?: true}}}}, _options),
    do: true

  def match?(_actor, %{subject: %{context: %{private: %{password_change?: true}}}}, _options),
    do: true

  def match?(_actor, _context, _options), do: false
end
