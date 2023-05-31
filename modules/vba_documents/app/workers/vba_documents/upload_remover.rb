# frozen_string_literal: true

require 'sidekiq'
require 'vba_documents/object_store'

module VBADocuments
  class UploadRemover
    include Sidekiq::Worker

    # No need to retry since the job is run every 30 seconds
    sidekiq_options retry: false, unique_for: 30.seconds

    EXPIRATION_TIME = 10.days

    REMOVAL_QUERY = <<-SQL.squish
        status IN ('received', 'processing', 'error', 'success', 'vbms')
        AND s3_deleted IS NOT True
        AND created_at < ?
    SQL

    def perform
      return unless Settings.vba_documents.s3.enabled

      rows = VBADocuments::UploadSubmission.select(:id, :guid, :status, :s3_deleted, :created_at)
                                           .where(REMOVAL_QUERY, EXPIRATION_TIME.ago)

      rows.find_in_batches do |batch|
        VBADocuments::UploadSubmission.transaction do
          batch.each do |upload|
            Rails.logger.info("VBADocuments: Cleaning up s3: #{upload.inspect}")

            store.delete(upload.guid) if store.object(upload.guid).exists?
          end

          # rubocop:disable Rails/SkipsModelValidations
          VBADocuments::UploadSubmission.where(id: batch.pluck(:id)).update_all(s3_deleted: true)
          # rubocop:enable Rails/SkipsModelValidations
        end
      end
    end

    def store
      @store ||= VBADocuments::ObjectStore.new
    end
  end
end
