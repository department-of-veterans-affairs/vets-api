# frozen_string_literal: true

module HCA
  class SubmissionJob
    include Sidekiq::Worker

    sidekiq_options unique_for: 30.minutes

    sidekiq_retries_exhausted do |msg, _e|
      health_care_application = HealthCareApplication.find(msg['args'][2])
      health_care_application.update_attributes!(state: 'failed', form: msg['args'][1].to_json)
    end

    def perform(user_uuid, form, health_care_application_id)
      health_care_application = HealthCareApplication.find(health_care_application_id)
      user = User.find(user_uuid)

      begin
        # TODO:  the following line is temporary, for testing
        raise HCA::SOAPParser::ValidationError if form['email'] =~ /oddball|adhocteam/
        result = HCA::Service.new(user).submit_form(form)
      rescue HCA::SOAPParser::ValidationError
        return health_care_application.update_attributes!(state: 'failed', form: form.to_json)
      rescue StandardError
        health_care_application.update_attributes!(state: 'error')
        raise
      end

      Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"

      health_care_application.set_result_on_success!(result)
    end
  end
end
