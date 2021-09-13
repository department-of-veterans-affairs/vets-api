# frozen_string_literal: true

module Middleware
  module Sidekiq
    require 'down_time_checker'
    class OnlyRunWhileUp
      def call(worker, job, _queue)
        if worker.respond_to?(:downtime_checks)
          array = worker.downtime_checks.map { |hash| DownTimeChecker.new(hash).down? }
          if array.all? { |element| element == false }
            yield
          else
            worker.class.perform_in(array.select(&:itself).max, job['args'])
          end
        else
          yield
        end
      end
    end
  end
end
