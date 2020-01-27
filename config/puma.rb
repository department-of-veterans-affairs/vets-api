# frozen_string_literal: true

plugin :statsd

workers Integer(ENV.fetch('PUMA_WORKERS', 0))
threads_count = Integer(ENV.fetch('PUMA_THREADS', 16))
threads(threads_count, threads_count)
