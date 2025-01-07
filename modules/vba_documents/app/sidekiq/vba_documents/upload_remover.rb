# frozen_string_literal: true

require 'sidekiq'
require 'vba_documents/object_store'

module VBADocuments
  class UploadRemover
    include Sidekiq::Job

    # No need to retry since the job is run every 30 seconds
    sidekiq_options retry: false, unique_for: 30.seconds

    EXPIRATION_TIME = 10.days

    REMOVAL_QUERY = <<-SQL.squish
        status IN ('received', 'processing', 'error', 'success', 'vbms')
        AND s3_deleted IS False
        AND created_at < ?
    SQL

    def perform
      return unless Settings.vba_documents.s3.enabled

      exp_time = EXPIRATION_TIME.ago

      loop do
        us_guids = VBADocuments::UploadSubmission.where(REMOVAL_QUERY, exp_time).select(:guid).limit(25).pluck(:guid)
        break if us_guids.empty?

        us_guids.each do |us_guid|
          Rails.logger.info("VBADocuments: Cleaning up s3: #{us_guid}")
          store.delete(us_guid)
        end

        # rubocop:disable Rails/SkipsModelValidations
        VBADocuments::UploadSubmission.where(guid: us_guids).update_all(s3_deleted: true)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end

    def store
      @store ||= VBADocuments::ObjectStore.new
    end
  end
end
