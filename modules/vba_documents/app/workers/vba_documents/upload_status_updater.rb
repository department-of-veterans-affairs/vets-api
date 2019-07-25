# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadStatusUpdater
    include Sidekiq::Worker

    sidekiq_options(
      queue: 'vba_documents',
      retry: true,
      unique_until: :success
    )

    def perform(submissions)
      submissions.each_slice(100) do |slice|
        VBADocuments::UploadSubmission.refresh_statuses!(slice)
      end
    end
  end
end
