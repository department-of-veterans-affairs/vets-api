# frozen_string_literal: true

module VBADocuments
  class UploadStatusBatch
    include Sidekiq::Worker

    sidekiq_options(
      retry: false,
      unique_until: :success
    )

    BATCH_SIZE = 100

    def perform
      if Settings.vba_documents.updater_enabled
        Sidekiq::Batch.new.jobs do
          filtered_submissions.each_slice(BATCH_SIZE) do |slice|
            VBADocuments::UploadStatusUpdater.perform_async(slice)
          end
        end
      end
    end

    def filtered_submissions
      where_str = "status = 'success' AND created_at < ?"
      VBADocuments::UploadSubmission
        .in_flight
        .where.not(where_str, VBADocuments::UploadSubmission::VBMS_IMPLEMENTATION_DATE)
        .order(created_at: :asc)
        .pluck(:guid)
    end
  end
end
