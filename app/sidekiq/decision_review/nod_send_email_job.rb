# frozen_string_literal: true

require 'decision_review_v1/utilities/logging_utils'

module DecisionReview
  class NodSendEmailJob
    include Sidekiq::Job
    include DecisionReviewV1::Appeals::LoggingUtils

    sidekiq_options retry: false

    LOG_PARAMS = {
      key: :nod_send_email_job,
      form_id: '10182',
      user_uuid: nil
    }.freeze

    def perform(email, template_id, line)
      Rails.logger.debug { "Starting send email job line: #{line} #{email}" }
      notify_client = VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
      notify_client.send_email({ email_address: email, template_id: })

      log_formatted(**LOG_PARAMS, is_success: true, params: { line: })
    rescue => e
      log_formatted(**LOG_PARAMS, is_success: false, params: { exception_message: e.message, line: })
    end
  end
end
