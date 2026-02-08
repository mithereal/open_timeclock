defmodule Timeclock.Mailer.Account.Confirmation do
  use Timeclock.Mailer, :premailx

  def process(
        user,
        url,
        subject \\ "Account Confirmation Needed!",
        sender \\ Timeclock.config([:timeclock, __MODULE__, :email_from_name]),
        email \\ Timeclock.config([:timeclock, __MODULE__, :email_from_address])
      ) do
    new()
    |> to({user.name, user.email})
    |> from({sender, email})
    |> subject(subject)
    |> render_body("account_confirmation.html", email: user.email, url: url)
    |> premail()
    |> deliver()
  end
end
