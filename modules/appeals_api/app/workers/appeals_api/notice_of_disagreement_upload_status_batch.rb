# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    BATCH_SIZE = 100

    def perform
      return unless enabled? && notice_of_disagreement_ids.present?

      Sidekiq::Batch.new.jobs do
        notice_of_disagreement_ids.each_slice(BATCH_SIZE).with_index do |ids, i|
          NoticeOfDisagreementUploadStatusUpdater.perform_in((i * 5).seconds, ids)
        end
      end
    end

    private

    def notice_of_disagreement_ids
      @notice_of_disagreement_ids ||= NoticeOfDisagreement.in_process_statuses.order(created_at: :asc).pluck(:id)
    end

    def enabled?
      Settings.modules_appeals_api.notice_of_disagreement_updater_enabled
    end
  end
end
