# frozen_string_literal: true

module Sidekiq
  require 'down_time_checker'
  class DowntimeCheckerMiddleware
    def call(worker, job, _queue)
      if should_do_downtime_checks?(worker) && services_down?(worker)
        reschedule_job(worker, job)
      else
        yield
      end
    end

    private

    def should_do_downtime_checks?(worker)
      worker.respond_to?(:downtime_checks)
    end

    def services_down?(worker)
      @downtime_checks_array = worker.downtime_checks.map { |hash| DownTimeChecker.new(hash).down? }
      @downtime_checks_array.any?
    end

    def reschedule_job(worker, job)
      worker.class.perform_in(time_until_up, *job['args'])
    end

    def time_until_up
      @downtime_checks_array.select(&:itself).max
    end
  end
end
