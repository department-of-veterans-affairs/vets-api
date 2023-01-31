# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class SupplementalClaimUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    BATCH_SIZE = 100

    def perform
      return unless enabled? && supplemental_claim_ids.present?

      Sidekiq::Batch.new.jobs do
        supplemental_claim_ids.each_slice(BATCH_SIZE).with_index do |ids, i|
          SupplementalClaimUploadStatusUpdater.perform_in((i * 5).seconds, ids)
        end
      end
    end

    private

    def supplemental_claim_ids
      @supplemental_claim_ids ||= SupplementalClaim.in_process_statuses.order(created_at: :asc).pluck(:id)
    end

    def enabled?
      Flipper.enabled? :decision_review_sc_status_updater_enabled
    end
  end
end
