defmodule Timeclock.Mailer.Password.Reset do
  use Timeclock.Mailer, :premailx

  def process(
        user,
        url,
        subject \\ "Account Action Needed!",
        sender \\ @sender,
        email \\ @noreply_email
      ) do
    new()
    |> to({user.name, user.email})
    |> from({sender, email})
    |> subject(subject)
    |> render_body("password_reset.html", %{username: user.name, url: url})
    |> premail()
    |> deliver()
  end
end
