# frozen_string_literal: true

module HCA
  class MockSubmissionJob < BaseSubmissionJob
    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 5

    sidekiq_retries_exhausted do |msg, _e|
      health_care_application = HealthCareApplication.find(msg['args'][2])
      form = decrypt_form(msg['args'][1])

      health_care_application.update!(
        state: 'failed',
        form: form.to_json,
        google_analytics_client_id: msg['args'][3]
      )
    end

    def perform(user_identifier, encrypted_form, health_care_application_id, google_analytics_client_id, succeed = true)
      # super
      @health_care_application = HealthCareApplication.find(health_care_application_id)

      Rails.logger.info '~~~~~~~~~~~~~~~ mock perform'
      raise unless succeed

      form = self.class.decrypt_form(encrypted_form)
      @health_care_application.form = form.to_json

      @health_care_application.set_result_on_success!(
        { success: true, formSubmissionId: 'mock_ves_form_id', timestamp: Time.current }
      )
    rescue
      @health_care_application.update!(state: 'error')
      Rails.logger.info '~~~~~~~~~~~~~~~ error'

      # message out failed submission when retries exhausted {state: "error"}
      raise
    end
  end
end
