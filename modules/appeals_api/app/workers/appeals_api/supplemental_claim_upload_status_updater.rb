# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

module AppealsApi
  class SupplementalClaimUploadStatusUpdater
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~30 minutes since the job that spawns this one runs every hour
    sidekiq_options retry: 5, unique_for: 30.minutes

    def perform(ids)
      batch_size = CentralMailUpdater::MAX_UUIDS_PER_REQUEST
      SupplementalClaim.where(id: ids).find_in_batches(batch_size:).with_index do |batch, i|
        CentralMailUpdater.new.call(batch)
        sleep 5 if i.positive? # Avoid flooding CMP with requests all at once
      end
    end

    def retry_limits_for_notification
      [5]
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end
  end
end
