# frozen_string_literal: true

workers ENV.fetch("WEB_CONCURRENCY") { 4 }

# Puma can serve each request in a thread from an internal thread pool.
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 10 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Use the `preload_app!` method when specifying a `workers` number.
preload_app!

# Allow puma to receive requests for 30 seconds before timing out
worker_timeout 30

# Increase the default timeout
worker_boot_timeout 60

# Set application port
port ENV.fetch("PORT") { 3000 }

# Specify the environment
environment ENV.fetch("RAILS_ENV") { "development" }

# used for a healthcheck endpoint that will not consume one of the threads
activate_control_app 'tcp://0.0.0.0:9293', { no_token: true }

on_worker_boot do
  SemanticLogger.reopen
  ActiveRecord::Base.establish_connection
end

# Bind to all interfaces
bind 'tcp://0.0.0.0:3000'

# Allow connections from all hosts
tag 'vets-api'

# Add connection timeout settings
persistent_timeout 20

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart
