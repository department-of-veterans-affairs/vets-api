# frozen_string_literal: true

plugin :statsd

workers Integer(ENV.fetch('WEB_CONCURRENCY', 0))
threads_count = Integer(ENV.fetch('PUMA_THREADS', 16))
threads(threads_count, threads_count)

# used for a healthcheck endpoint that will not consume one of the threads
activate_control_app 'tcp://0.0.0.0:9293', { no_token: true }

on_worker_boot do
  SemanticLogger.reopen
  ActiveRecord::Base.establish_connection
end
