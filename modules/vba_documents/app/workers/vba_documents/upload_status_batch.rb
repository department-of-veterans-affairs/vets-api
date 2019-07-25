# frozen_string_literal: true

module VBADocuments
  class UploadStatusBatch
    DIVISION_SIZE = 3
    def perform
      if Settings.vba_documents.updater_enabled
        batch = Sidekiq::Batch.new
        submissions = VBADocuments::UploadSubmission.in_flight.order(created_at: :asc)
        batch.jobs do
          submissions.each_slice(submissions.count / DIVISION_SIZE) do |slice|
            VBADocuments::UploadStatusUpdater.perform_async(slice)
          end
        end
      end
    end
  end
end
