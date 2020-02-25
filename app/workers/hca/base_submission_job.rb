# frozen_string_literal: true

module HCA
  class BaseSubmissionJob
    include Sidekiq::Worker
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError

    def perform(user_identifier, form, health_care_application_id, google_analytics_client_id)
      health_care_application = HealthCareApplication.find(health_care_application_id)

      begin
        result = HCA::Service.new(user_identifier).submit_form(form)
      rescue VALIDATION_ERROR
        PersonalInformationLog.create!(data: { form: form }, error_class: VALIDATION_ERROR.to_s)

        return health_care_application.update_attributes!(
          state: 'failed',
          form: form.to_json,
          google_analytics_client_id: google_analytics_client_id
        )
      rescue
        health_care_application.update_attributes!(state: 'error')
        raise
      end

      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"

      health_care_application.set_result_on_success!(result)
    end
  end
end
