# frozen_string_literal: true

module HCA
  class SubmissionJob < BaseSubmissionJob
    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    sidekiq_retries_exhausted do |msg, _e|
      health_care_application = HealthCareApplication.find(msg['args'][2])
      form = decrypt_form(msg['args'][1])

      health_care_application.update!(
        state: 'failed',
        form: form.to_json,
        google_analytics_client_id: msg['args'][3]
      )
    end

    def perform(*args)
      super
    rescue
      @health_care_application.update!(state: 'error')

      raise
    end
  end
end
