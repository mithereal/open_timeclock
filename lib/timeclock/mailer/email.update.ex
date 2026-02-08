defmodule Timeclock.Mailer.Email.Update do
  use Timeclock.Mailer, :premailx

  def process(
        user,
        url,
        subject \\ "Account Action Needed!",
        sender \\ Timeclock.config([:timeclock, __MODULE__, :email_from_name]),
        email \\ Timeclock.config([:timeclock, __MODULE__, :email_from_address])
      ) do
    new()
    |> to({user.name, user.email})
    |> from({sender, email})
    |> subject(subject)
    |> render_body("email_update.html", %{username: user.name, url: url})
    |> premail()
    |> deliver()
  end
end
