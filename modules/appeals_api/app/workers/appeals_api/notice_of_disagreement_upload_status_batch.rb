# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementUploadStatusBatch
    include Sidekiq::Worker

    sidekiq_options 'retry': true, unique_until: :success

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
      @notice_of_disagreement_ids ||= NoticeOfDisagreement.received_or_processing.order(created_at: :asc).pluck(:id)
    end

    def slice_size
      (notice_of_disagreement_ids.length / 5.0).ceil
    end

    def enabled?
      Settings.modules_appeals_api.notice_of_disagreement_updater_enabled
    end
  end
end
