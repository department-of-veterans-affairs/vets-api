# frozen_string_literal: true

require 'sidekiq'
require 'vba_documents/object_store'

module VBADocuments
  class UploadRemover
    include Sidekiq::Worker

    EXPIRATION_TIME = 3.days

    def perform
      return unless Settings.vba_documents.s3.enabled
      VBADocuments::UploadSubmission.where(
        "status = 'received' AND s3_deleted IS NOT True and created_at < ?", EXPIRATION_TIME.ago
      ).find_each do |upload|
        Rails.logger.info('VBADocuments: Cleaning up s3: ' + upload.inspect)
        break unless store.object(upload.guid).exists?
        store.delete(upload.guid)
        upload.update(s3_deleted: true)
      end
    end

    def store
      @store ||= VBADocuments::ObjectStore.new
    end
  end
end

