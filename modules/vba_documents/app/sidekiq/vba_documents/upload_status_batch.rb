# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadStatusBatch
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 1.hour

    BATCH_SIZE = 100

    def perform
      return unless enabled? && filtered_submission_guids.present?

      Sidekiq::Batch.new.jobs do
        filtered_submission_guids.each_slice(BATCH_SIZE).with_index do |guids, i|
          # Stagger jobs by a few seconds so that we don't overwhelm the upstream service
          VBADocuments::UploadStatusUpdater.perform_in((i * 5).seconds, guids)
        end
      end
    end

    private

    def filtered_submission_guids
      VBADocuments::UploadSubmission.in_flight.order(created_at: :asc).pluck(:guid)
    end

    def enabled?
      Settings.vba_documents.updater_enabled
    end
  end
end
