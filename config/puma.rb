# frozen_string_literal: true

plugin :statsd

workers Integer(ENV.fetch('PUMA_WORKERS', 0))
threads_count = Integer(ENV.fetch('PUMA_THREADS', 16))
threads(threads_count, threads_count)

if ENV.fetch('PUMA_PRELOAD', false)
  preload_app!

  on_worker_boot do
    SemanticLogger.reopen
    ActiveRecord::Base.establish_connection
  end
end
