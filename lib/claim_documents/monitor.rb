# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module ClaimDocuments
  ##
  # Monitor functions for Rails logging and StatsD
  # @todo abstract, split logging for controller and sidekiq
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # statsd key for document uploads
    DOCUMENT_STATS_KEY = 'api.document_upload'

    def track_document_upload_attempt(form_id, current_user)
      StatsD.increment("#{DOCUMENT_STATS_KEY}.attempt", tags: ["form_id: #{form_id}"])
      Rails.logger.info("Creating PersistentAttachment FormID=#{form_id}",
                        { user_account_uuid: current_user&.user_account_uuid,
                          statsd: "#{DOCUMENT_STATS_KEY}.attempt" })
    end

    def track_document_upload_success(form_id, attachment_id, current_user)
      StatsD.increment("#{DOCUMENT_STATS_KEY}.success", tags: ["form_id: #{form_id}"])
      Rails.logger.info("Success creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id}",
                        { attachment_id:, user_account_uuid: current_user&.user_account_uuid,
                          statsd: "#{DOCUMENT_STATS_KEY}.success" })
    end

    def track_document_upload_failed(form_id, attachment_id, current_user, e)
      StatsD.increment("#{DOCUMENT_STATS_KEY}.failure", tags: ["form_id: #{form_id}"])
      log_silent_failure({ form_id: form_id, attachment_id: attachment_id }, current_user&.user_account_uuid)
      Rails.logger.error("Error creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id} #{e}",
                         { attachment_id:, user_account_uuid: current_user&.user_account_uuid,
                           statsd: "#{DOCUMENT_STATS_KEY}.failure", message: e&.message })
    end
  end
end
