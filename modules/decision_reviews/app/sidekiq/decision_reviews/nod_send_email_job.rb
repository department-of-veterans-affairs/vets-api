# frozen_string_literal: true

require 'decision_reviews/v1/logging_utils'

module DecisionReviews
  class NodSendEmailJob
    include Sidekiq::Job
    include DecisionReviews::V1::LoggingUtils

    sidekiq_options retry: false

    LOG_PARAMS = {
      key: :nod_send_email_job,
      form_id: '10182',
      user_uuid: nil
    }.freeze

    def perform(email_address, template_id, personalisation, line_num)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.benefits_decision_review.api_key)
      notify_client.send_email({ email_address:, template_id:, personalisation: })

      log_formatted(**LOG_PARAMS, is_success: true, params: { line_num: })
    rescue => e
      log_formatted(**LOG_PARAMS, is_success: false, params: { exception_message: e.message, line_num: })
    end
  end
end
