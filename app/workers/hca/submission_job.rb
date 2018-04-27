# frozen_string_literal: true

module HCA
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_retries_exhausted do |msg, _e|
      health_care_application = HealthCareApplication.find(msg['args'][2])
      health_care_application.update_attributes!(state: 'failed')
    end

    def perform(user_uuid, form, health_care_application_id)
      health_care_application = HealthCareApplication.find(health_care_application_id)
      user = User.find(user_uuid)

      begin
        result = HCA::Service.new(user).submit_form(form)
      rescue StandardError => e
        health_care_application.update_attributes!(state: 'error')
        raise e
      end

      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"

      health_care_application.set_result_on_success!(result)
    end
  end
end
