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

    def perform
      VBADocuments::UploadSubmission.in_flight.order(created_at: :asc).find_in_batches(batch_size: 100).each do |batch|
        VBADocuments::UploadSubmission.refresh_statuses!(batch)
      end
    end
  end
end
