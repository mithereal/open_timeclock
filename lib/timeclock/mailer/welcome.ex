defmodule Timeclock.Mailer.Welcome do
  use Timeclock.Mailer, :premailx

  def process(user, subject \\ "Welcome to our Site!", sender \\ @sender, email \\ @noreply_email) do
    new()
    |> to({user.name, user.email})
    |> from({sender, email})
    |> subject(subject)
    |> render_body("welcome.html", %{username: user.name})
    |> premail()
    |> deliver()
  end
end
