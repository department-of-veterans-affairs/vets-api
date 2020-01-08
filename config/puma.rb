# frozen_string_literal: true

plugin :statsd

# Configure "min" to be the minimum number of threads to use to answer
# requests and "max" the maximum.
#
# The default is "0, 16".
#
threads 16, 16

# === Cluster mode ===

# How many worker processes to run.
#
# The default is "0".
#
workers 1

# Verifies that all workers have checked in to the master process within
# the given timeout. If not the worker process will be restarted. Default
# value is 60 seconds.
#
worker_timeout 60

on_worker_boot do
  ActiveRecord::Base.establish_connection # can also connect Resque/redis here since we use a lot of that
end
