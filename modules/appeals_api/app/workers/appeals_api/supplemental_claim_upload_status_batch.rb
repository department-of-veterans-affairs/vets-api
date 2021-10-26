# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class SupplementalClaimUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false

    def perform
      return unless enabled? && supplemental_claim_ids.present?

      Sidekiq::Batch.new.jobs do
        supplemental_claim_ids.each_slice(slice_size) do |ids|
          SupplementalClaimUploadStatusUpdater.perform_async(ids)
        end
      end
    end

    private

    def supplemental_claim_ids
      @supplemental_claim_ids ||= SupplementalClaim.in_process_statuses.order(created_at: :asc).pluck(:id)
    end

    def slice_size
      (supplemental_claim_ids.length / 5.0).ceil
    end

    def enabled?
      Settings.modules_appeals_api.supplemental_claim_updater_enabled
    end
  end
end
