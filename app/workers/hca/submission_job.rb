# frozen_string_literal: true

module HCA
  class SubmissionJob < BaseSubmissionJob
    sidekiq_retries_exhausted do |msg, _e|
      health_care_application = HealthCareApplication.find(msg['args'][2])
      health_care_application.update_attributes!(
        state: 'failed',
        form: msg['args'][1].to_json,
        google_analytics_client_id: msg['args'][3]
      )
    end
  end
end
