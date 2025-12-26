import Config

# Configure repos from dependencies to prevent connection errors during tests.
# These repos are not actually used by crucible_deployment tests.

config :crucible_framework, CrucibleFramework.Repo,
  database: "crucible_framework_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

config :crucible_model_registry, CrucibleModelRegistry.Repo,
  database: "crucible_model_registry_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
