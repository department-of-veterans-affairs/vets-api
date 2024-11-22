# frozen_string_literal: true

workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Allow puma to be restarted by `rails restart` command.
plugin :tmp_restart

# Increase timeouts for load testing
persistent_timeout 120
first_data_timeout 120

# used for a healthcheck endpoint that will not consume one of the threads
activate_control_app 'tcp://0.0.0.0:9293', { no_token: true }

on_worker_boot do
  SemanticLogger.reopen
  ActiveRecord::Base.establish_connection
end
