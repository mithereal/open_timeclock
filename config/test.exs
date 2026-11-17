import Config

config :timeclock, Oban, testing: :manual
config :timeclock, token_signing_secret: "c/4H8uGOQMaOQD/Mr4NGKyB5YYpZISXp"
config :bcrypt_elixir, log_rounds: 1

config :ash,
  policies: [show_policy_breakdowns?: true, private_fields: :hide],
  disable_async?: true

# Configure your database
config :timeclock, Timeclock.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "timeclock_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test
config :timeclock, TimeclockWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "kg/5Qj8+iLUmvJhfrSyqkD6nYbS5hNLiiFK8C2fjbdIGUmjEqGOLKHulyxfS3LSf",
  server: false

# In test we don't send emails
config :timeclock, Timeclock.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful runtime checks during tests
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Deterministic 32-byte Base64 encryption key for Cloak in test runs
test_cloak_key =
  System.get_env("CLOAK_KEY") || "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="

config :timeclock, Timeclock.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(test_cloak_key)}
  ]
