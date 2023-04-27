# frozen_string_literal: true

require 'benchmark'

module Sidekiq
  module BenchmarkLoggingWorker
    # This module serves to mark workers which should log benchmarking information.
    # Actual logging takes place in Sidekiq::Middleware::BenchmarkLoggingMiddleware.
  end
end
