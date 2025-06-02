# frozen_string_literal: true

require 'hca/service'
require 'hca/soap_parser'

module HCA
  class SubmissionJob
    include Sidekiq::Job
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError

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

    def self.decrypt_form(encrypted_form)
      JSON.parse(HealthCareApplication::LOCKBOX.decrypt(encrypted_form))
    end

    def submit(user_identifier, form, google_analytics_client_id)
      begin
        result = HCA::Service.new(user_identifier).submit_form(form)
      rescue VALIDATION_ERROR
        handle_enrollment_system_validation_error(form, google_analytics_client_id)
        return false
      end

      result
    end

    def perform(user_identifier, encrypted_form, health_care_application_id, google_analytics_client_id)
      @health_care_application = HealthCareApplication.find(health_care_application_id)
      form = self.class.decrypt_form(encrypted_form)

      result = submit(user_identifier, form, google_analytics_client_id)
      return unless result

      Rails.logger.info "[10-10EZ] - SubmissionID=#{result[:formSubmissionId]}"
      @health_care_application.form = form.to_json
      @health_care_application.set_result_on_success!(result)
    rescue
      @health_care_application.update!(state: 'error')

      raise
    end

    private

    def handle_enrollment_system_validation_error(form, google_analytics_client_id)
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.enrollment_system_validation_error")
      PersonalInformationLog.create!(
        data: { form: },
        error_class: VALIDATION_ERROR.to_s
      )

      @health_care_application.update!(
        state: 'failed',
        form: form.to_json,
        google_analytics_client_id:
      )
    end
  end
end
