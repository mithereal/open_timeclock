defmodule Timeclock.Mailer.Welcome do
  use Timeclock.Mailer, :premailx

  def process(
        user,
        subject \\ "Welcome to our Site!",
        sender \\ Timeclock.config([:timeclock, __MODULE__, :email_from_name]),
        email \\ Timeclock.config([:timeclock, __MODULE__, :email_from_address])
      ) do
    new()
    |> to({user.name, user.email})
    |> from({sender, email})
    |> subject(subject)
    |> render_body("welcome.html", %{username: user.name})
    |> premail()
    |> deliver()
  end
end
