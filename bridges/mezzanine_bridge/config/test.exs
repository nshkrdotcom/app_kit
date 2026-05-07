import Config

config :mezzanine_audit_engine, start_runtime_children?: true
config :mezzanine_config_registry, start_runtime_children?: true
config :mezzanine_object_engine, start_runtime_children?: true
config :mezzanine_execution_engine, start_runtime_children?: true
config :mezzanine_decision_engine, start_runtime_children?: true
config :mezzanine_evidence_engine, start_runtime_children?: true
config :mezzanine_archival_engine, start_runtime_children?: true
config :mezzanine_ops_domain, start_runtime_children?: true

config :mezzanine_audit_engine, Mezzanine.Audit.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_app_kit_bridge_substrate_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_config_registry, Mezzanine.ConfigRegistry.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_config_registry_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_object_engine, Mezzanine.Objects.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_app_kit_bridge_substrate_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_execution_engine, Mezzanine.Execution.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_app_kit_bridge_substrate_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_execution_engine, Oban,
  name: Mezzanine.Execution.Oban,
  repo: Mezzanine.Execution.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  peer: false,
  queues: false,
  plugins: false,
  testing: :manual

config :mezzanine_decision_engine, Mezzanine.Decisions.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_app_kit_bridge_substrate_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_evidence_engine, Mezzanine.EvidenceLedger.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_app_kit_bridge_substrate_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_archival_engine, Mezzanine.Archival.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_app_kit_bridge_substrate_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true

config :mezzanine_ops_domain, Mezzanine.OpsDomain.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mezzanine_ops_domain_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 10_000,
  queue_interval: 20_000,
  show_sensitive_data_on_connection_error: true
