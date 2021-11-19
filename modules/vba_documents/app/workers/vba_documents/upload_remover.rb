# frozen_string_literal: true

require 'sidekiq'
require 'vba_documents/object_store'

module VBADocuments
  class UploadRemover
    include Sidekiq::Worker

    EXPIRATION_TIME = 10.days

    REMOVAL_QUERY = <<-SQL.squish
        status IN ('received', 'processing', 'error', 'success', 'vbms')
        AND s3_deleted IS NOT True
        AND created_at < ?
    SQL

    def perform
      return unless Settings.vba_documents.s3.enabled

      rows = VBADocuments::UploadSubmission.where(REMOVAL_QUERY, EXPIRATION_TIME.ago)

      rows.find_each do |upload|
        Rails.logger.info("VBADocuments: Cleaning up s3: #{upload.inspect}")
        store.delete(upload.guid) if store.object(upload.guid).exists?
        upload.s3_deleted = true
        upload.save!(touch: false)
      end
    end

    def store
      @store ||= VBADocuments::ObjectStore.new
    end
  end
end
