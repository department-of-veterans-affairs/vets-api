# frozen_string_literal: true

require 'pagerduty/maintenance_client'
require 'vets/shared_logging'

module PagerDuty
  class PollMaintenanceWindows
    include Sidekiq::Job
    include Vets::SharedLogging
    sidekiq_options retry: 1, queue: 'critical'

    MESSAGE_INDICATOR = 'USER_MESSAGE:'

    def parse_user_message(raw_description)
      raw_description.partition(MESSAGE_INDICATOR)[2].strip
    end

    def perform
      client = PagerDuty::MaintenanceClient.new
      pd_windows = client.get_all

      # Add or update-in-place any open PagerDuty maintenance windows
      pd_windows.each do |pd_win|
        pd_win[:description] = parse_user_message(pd_win[:description])
        window = MaintenanceWindow.find_or_initialize_by(pagerduty_id: pd_win[:pagerduty_id],
                                                         external_service: pd_win[:external_service])
        window.update(pd_win)
      end

      # Delete any existing records that are not present in the PagerDuty API results
      # These indicate deleted maintenance windows so we want to stop reporting them
      open_ids = pd_windows.pluck(:pagerduty_id)
      MaintenanceWindow.end_after(Time.zone.now).each do |api_win|
        api_win.delete unless open_ids.include?(api_win.pagerduty_id)
      end
    rescue Common::Exceptions::BackendServiceException, Common::Client::Errors::ClientError => e
      log_exception_to_sentry(e)
    end
  end
end
