# frozen_string_literal: true

require 'hca/service'
require 'hca/soap_parser'

module HCA
  class BaseEncryptedSubmissionJob
    include Sidekiq::Worker
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError

    def self.decrypt_form(encrypted_form)
      JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_form))
    end

    def submit(user_identifier, form, google_analytics_client_id)
      begin
        result = HCA::Service.new(user_identifier).submit_form(form)
      rescue VALIDATION_ERROR
        PersonalInformationLog.create!(data: { form: }, error_class: VALIDATION_ERROR.to_s)

        @health_care_application.update!(
          state: 'failed',
          form: form.to_json,
          google_analytics_client_id:
        )

        return false
      end

      result
    end

    def perform(user_identifier, encrypted_form, health_care_application_id, google_analytics_client_id)
      @health_care_application = HealthCareApplication.find(health_care_application_id)
      form = self.class.decrypt_form(encrypted_form)

      result = submit(user_identifier, form, google_analytics_client_id)
      return unless result

      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"

      @health_care_application.set_result_on_success!(result)
    end
  end
end
