# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadStatusUpdater
    include Sidekiq::Worker

    sidekiq_options(
      retry: true,
      unique_until: :success
    )

    BATCH_SIZE = 100

    def perform(submission_guids)
      VBADocuments::UploadSubmission.where(guid: submission_guids).find_in_batches(batch_size: BATCH_SIZE) do |slice|
        VBADocuments::UploadSubmission.refresh_statuses!(slice)
      end
    end
  end
end
