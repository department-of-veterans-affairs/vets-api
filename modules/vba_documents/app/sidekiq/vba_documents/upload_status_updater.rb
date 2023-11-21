# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadStatusUpdater
    include Sidekiq::Job

    # Only retry for ~30 minutes since the job that spawns this one runs every hour
    sidekiq_options retry: 5, unique_for: 1.hour

    BATCH_SIZE = 100

    def perform(submission_guids)
      VBADocuments::UploadSubmission.where(guid: submission_guids).find_in_batches(batch_size: BATCH_SIZE) do |group|
        VBADocuments::UploadSubmission.refresh_statuses!(group)
      end
    end
  end
end
