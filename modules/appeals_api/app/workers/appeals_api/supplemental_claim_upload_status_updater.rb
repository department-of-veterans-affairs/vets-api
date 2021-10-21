# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

module AppealsApi
  class SupplementalClaimUploadStatusUpdater
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~30 minutes since the job that spawns this one runs every hour
    sidekiq_options retry: 5, unique_until: :success

    def perform(ids)
      batch_size = CentralMailUpdater::MAX_UUIDS_PER_REQUEST
      SupplementalClaim.where(id: ids).find_in_batches(batch_size: batch_size) do |batch|
        CentralMailUpdater.new.call(batch)
      end
    end

    def retry_limits_for_notification
      if Settings.vsp_environment == 'production'
        [2, 4]
      else
        [5]
      end
    end

    def notify(retry_params)
      AppealsApi::Slack::Messager.new(retry_params, notification_type: :error_retry).notify!
    end
  end
end
