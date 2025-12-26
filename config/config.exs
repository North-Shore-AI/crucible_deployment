import Config

# Configure target/strategy/converter overrides in your application as needed.

# Import environment specific config at the end
import_config "#{config_env()}.exs"
