defmodule Timeclock.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender
  use TimeclockWeb, :verified_routes

  import Swoosh.Email
  alias Timeclock.Mailer

  @impl true
  def send(user, token, _) do
    Timeclock.Mailer.Account.MagicLink.process(user, url(~p"/magic_link/#{token}"))
  end
end
