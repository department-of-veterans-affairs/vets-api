# frozen_string_literal: true

# Job that reqs statsu updates for NODs that hit a processing error within EMMS API.
# These errors sometimes recover within EMMS, so continue to poll EMMS for status changes
require 'sidekiq'

module AppealsApi
  class SupplementalClaimUploadErrorStatusBatch
    include Sidekiq::Job

    # No need to retry since the schedule will run this regularly
    sidekiq_options retry: false, unique_for: 30.minutes

    # Age in days to continue to update the status of NODs with an upstream DOC202 procesing error
    DOC202_ERROR_STATUS_UPDATE_LOOKBACK = 14.days

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
      @notice_of_disagreement_ids ||=
        NoticeOfDisagreement.where(status: 'error', code: 'DOC202')
                            .where('created_at >= ?', DOC202_ERROR_STATUS_UPDATE_LOOKBACK.ago)
                            .order(created_at: :asc).pluck(:id)
    end

    def enabled?
      Flipper.enabled? :decision_review_nod_status_updater_enabled
    end
  end
end
