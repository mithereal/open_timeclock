defmodule Timeclock.MixProject do
  use Mix.Project

  def project do
    [
      app: :timeclock,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Timeclock.Application, []},
      extra_applications: [:logger, :runtime_tools, :glific_phil_columns]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:oban, "~> 2.0"},
      {:ash_oban, "~> 0.7"},
      {:cinder, "~> 0.8"},
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.8"},
      {:live_debugger, "~> 0.5", only: [:dev]},
      {:ash_admin, "~> 0.13"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_commanded, "~> 0.2.0"},
      {:ash, "~> 3.0"},
      {:igniter, ">= 0.0.0"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0", override: true},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.21"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:ash_sqids, "~> 0.1.0"},
      {:phoenix_live_favicon, "~> 1.0.0"},
      {:premailex, "~> 0.3.0"},
      {:phoenix_swoosh, "~> 1.2"},
      {:mishka_chelekom, "~> 0.0.8", only: :dev},
      {:plug_health, "~> 0.1.0"},
      {:observer_cli, "~> 1.8"},
      {:maybe, "~> 1.0"},
      {:phoenix_copy, ">= 0.0.0"},
      {:gen_smtp, "~> 1.2"},
      {:hackney, ">= 0.0.0"},
      {:recase, "~> 0.5"},
      {:live_charts, "~> 0.4.0"},
      {:cors_plug, "~> 3.0"},
      {:ex_cldr, "~> 2.46"},
      {:cloak_ecto, "~> 1.3"},
      {:tz, "~> 0.28"},
      {:ash_paper_trail, "~> 0.5.7"},
      {:ash_archival, "~> 2.0.3"},
      {:glific_phil_columns, "~> 3.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      seed: ["phil_columns.seed"],
      migrations: ["ash_postgres.generate_migrations resources"],
      setup: [
        "deps.get",
        "ash.setup",
        "ash_postgres.generate_migrations resources",
        "assets.setup",
        "assets.build",
        "run priv/repo/seeds.exs"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind timeclock", "esbuild timeclock"],
      "assets.deploy": [
        "tailwind timeclock --minify",
        "esbuild timeclock --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
