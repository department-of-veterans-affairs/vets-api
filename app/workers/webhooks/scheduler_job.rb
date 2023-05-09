# frozen_string_literal: true

require './lib/webhooks/utilities'

module Webhooks
  class SchedulerJob
    include Sidekiq::Worker

    def perform(api_name = nil, processing_time = nil)
      results = []
      Rails.logger.info "Webhooks::SchedulerJob SchedulerJob.perform #{api_name} at time #{processing_time}"
      if api_name.nil?
        Webhooks::Utilities.api_name_to_time_block.each_pair do |name, block|
          results << go(name, processing_time, block)
        end
      else
        results << go(api_name, processing_time, Webhooks::Utilities.api_name_to_time_block[api_name])
      end
      results
    rescue => e
      Rails.logger.error("Webhooks::SchedulerJob Error in SchedulerJob #{e.message}", e)
      # we try again in 5 minutes
      Webhooks::SchedulerJob.perform_in(5.minutes.from_now, api_name)
    end

    private

    def go(api_name, last_run, block)
      result = []
      Rails.logger.info "Webhooks::SchedulerJob SchedulerJob.go  #{api_name} at time #{last_run}"
      begin
        time_to_start = begin
          block.call(last_run)
        rescue
          1.hour.from_now
        end
        result << time_to_start
        result << Webhooks::NotificationsJob.perform_in(time_to_start, api_name)
        Rails.logger.info "Webhooks::SchedulerJob kicked off #{api_name} at time #{time_to_start}"
      rescue => e
        Rails.logger.error("Webhooks::SchedulerJob Failed to kick of jobs for api_name #{api_name}", e)
        result = nil
      end
      result
    end
  end
end
