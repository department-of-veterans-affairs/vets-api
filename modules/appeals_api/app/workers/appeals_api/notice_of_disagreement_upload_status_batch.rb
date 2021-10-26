# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false

    def perform
      return unless enabled? && notice_of_disagreement_ids.present?

      Sidekiq::Batch.new.jobs do
        notice_of_disagreement_ids.each_slice(slice_size) do |ids|
          NoticeOfDisagreementUploadStatusUpdater.perform_async(ids)
        end
      end
    end

    private

    def notice_of_disagreement_ids
      @notice_of_disagreement_ids ||= NoticeOfDisagreement.in_process_statuses.order(created_at: :asc).pluck(:id)
    end

    def slice_size
      (notice_of_disagreement_ids.length / 5.0).ceil
    end

    def enabled?
      Settings.modules_appeals_api.notice_of_disagreement_updater_enabled
    end
  end
end
