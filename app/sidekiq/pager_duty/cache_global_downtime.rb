# frozen_string_literal: true

require 'vets/shared_logging'

require 'pagerduty/maintenance_client'
require 'pagerduty/maintenance_windows_uploader'

module PagerDuty
  class CacheGlobalDowntime
    include Sidekiq::Job
    include Vets::SharedLogging
    sidekiq_options retry: 1, queue: 'critical'

    def perform
      client = PagerDuty::MaintenanceClient.new
      options = { 'service_ids' => [global_service_id] }
      maintenance_windows = client.get_all(options)
      file_path = 'tmp/maintenance_windows.json'

      File.open(file_path, 'w') do |f|
        f << maintenance_windows.to_json
      end

      PagerDuty::MaintenanceWindowsUploader.upload_file(file_path)
    rescue Common::Exceptions::BackendServiceException, Common::Client::Errors::ClientError => e
      log_exception_to_sentry(e)

      log_exception_to_rails(e)
    end

    private

    def global_service_id
      Settings.maintenance.services&.to_hash&.dig(:global)
    end
  end
end
