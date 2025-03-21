# frozen_string_literal: true

require 'logging/monitor'

module ClaimDocuments
  ##
  # Monitor functions for Rails logging and StatsD
  # @todo abstract, split logging for controller and sidekiq
  #
  class Monitor < ::Logging::Monitor
    # statsd key for document uploads
    DOCUMENT_STATS_KEY = 'api.claim_documents'

    def initialize
      super('claim_documents')
    end

    def track_document_upload_attempt(form_id, current_user)
      additional_context = {
        user_account_uuid: current_user&.user_account_uuid,
        tags: ["form_id:#{form_id}"]
      }
      track_request('info', "Creating PersistentAttachment FormID=#{form_id}", "#{DOCUMENT_STATS_KEY}.attempt",
                    **additional_context)
    end

    def track_document_upload_success(form_id, attachment_id, current_user)
      additional_context = {
        attachment_id:,
        user_account_uuid: current_user&.user_account_uuid,
        tags: ["form_id:#{form_id}"]
      }
      track_request('info', "Success creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id}",
                    "#{DOCUMENT_STATS_KEY}.success", **additional_context)
    end

    def track_document_upload_failed(form_id, attachment_id, current_user, e)
      additional_context = {
        attachment_id:,
        user_account_uuid: current_user&.user_account_uuid,
        tags: ["form_id:#{form_id}"],
        message: e&.message
      }
      track_request('error', "Error creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id} #{e}",
                    "#{DOCUMENT_STATS_KEY}.failure", **additional_context)
    end

    def track_document_upload_input_error(form_id, attachment_id, current_user, e)
      additional_context = {
        attachment_id:,
        user_account_uuid: current_user&.user_account_uuid,
        tags: ["form_id:#{form_id}"],
        message: e&.message
      }
      track_request('error',
                    "Input error creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id} #{e}",
                    "#{DOCUMENT_STATS_KEY}.input_error", **additional_context)
    end
  end
end
