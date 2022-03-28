# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

module AppealsApi
  class NoticeOfDisagreementUploadStatusUpdater
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    # Only retry for ~30 minutes since the job that spawns this one runs every hour
    sidekiq_options retry: 5, unique_until: :success

    def perform(ids)
      batch_size = CentralMailUpdater::MAX_UUIDS_PER_REQUEST
      NoticeOfDisagreement.where(id: ids).find_in_batches(batch_size: batch_size) do |batch|
        CentralMailUpdater.new.call(batch)
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
