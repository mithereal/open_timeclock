defmodule Timeclock.Mailer.Account.MagicLink do
  use Timeclock.Mailer, :premailx

  def process(
        user,
        url,
        subject \\ "Account Login!",
        sender \\ @sender,
        email \\ @noreply_email
      ) do
    new()
    |> to(user.email)
    |> from({sender, email})
    |> subject(subject)
    |> render_body("magic_link.html", magic_link: url)
    |> premail()
    |> deliver()
  end
end
