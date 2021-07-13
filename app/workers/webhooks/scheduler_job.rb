# frozen_string_literal: true
require_dependency './lib/webhooks/utilities'
require_dependency './app/workers/webhooks/notifications_job'

module Webhooks
  class SchedulerJob
    include Sidekiq::Worker

    def perform(api_name = nil, processing_time = nil)
      Rails.logger.info "CRIS SchedulerJob.perform #{api_name} at time #{processing_time}"
      if (api_name.nil?)
        Webhooks::Utilities.api_name_to_time_block.each_pair do |name, block|
          go(name, processing_time, block)
        end
      else
        go(api_name, processing_time, Webhooks::Utilities.api_name_to_time_block[api_name])
      end
    rescue => e
      Rails.logger.error("CRIS Error in SchedulerJob #{e.message}", e)
    end

    private

    def go(api_name, last_run, block)
      Rails.logger.info "CRIS SchedulerJob.go  #{api_name} at time #{last_run}"
      begin
        time_to_start = block.call(last_run)
        Webhooks::NotificationsJob.perform_in(time_to_start, api_name)
        Rails.logger.info "CRIS kicked off #{api_name} at time #{time_to_start}, current time is #{Time.now}"
      rescue => e
        Rails.logger.error("CRIS Failed to kick of jobs for api_name #{api_name}", e)
      end
    end
  end
end
