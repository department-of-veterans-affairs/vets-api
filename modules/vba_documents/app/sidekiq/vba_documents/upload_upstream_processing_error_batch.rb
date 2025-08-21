# frozen_string_literal: true
# Job polls EMMS for status updates for UploadSubmission that hit an EMMS internal procession error.  EMMS seems
# to have re-processing capacitity and some EMMS errors self recover
require 'sidekiq'

module VBADocuments
  class UploadUpstreamProcessingErrorBatch
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 1.hour

    BATCH_SIZE = 100

    def perform
      return unless enabled? 
      
      us_guids = filtered_submission_guids
      return unless us_guids.present?

      Sidekiq::Batch.new.jobs do
        us_guids.each_slice(BATCH_SIZE).with_index do |guids, i|
          # Stagger jobs by a few seconds so that we don't overwhelm the upstream service
          VBADocuments::UploadStatusUpdater.perform_in((i * 5).seconds, guids)
        end
      end
    end

    private

    def filtered_submission_guids
      ups = VBADocuments::UploadSubmission.emms_internal_processing_error
      ups = ups.where("created_at >= ?", UploadSubmission::MAX_UPSTREAM_ERROR_AGE_DAYS.days.ago)
      ups.order(created_at: :asc).pluck(:guid)
    end

    def enabled?
      Settings.vba_documents.updater_enabled
    end
  end
end
