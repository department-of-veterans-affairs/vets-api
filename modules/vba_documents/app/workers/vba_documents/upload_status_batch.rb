# frozen_string_literal: true

module VBADocuments
  class UploadStatusBatch
    include Sidekiq::Worker

    sidekiq_options(
      retry: true,
      unique_until: :success
    )

    # We don't want to check successes before
    # this date as it used to be the endpoint
    VBMS_IMPLEMENTATION_DATE = Date.parse('28-06-2019')
    DIVISION_SIZE = 5.0

    def perform
      if Settings.vba_documents.updater_enabled
        Sidekiq::Batch.new.jobs do
          submissions = filtered_submissions
          slice_size = (submissions.count / DIVISION_SIZE).ceil
          submissions.each_slice(slice_size) do |slice|
            VBADocuments::UploadStatusUpdater.perform_async(slice)
          end
        end
      end
    end

    def filtered_submissions
      VBADocuments::UploadSubmission
        .in_flight
        .where.not("status = 'success' AND created_at < ?", VBMS_IMPLEMENTATION_DATE)
        .order(created_at: :asc)
        .pluck(:guid)
    end
  end
end
