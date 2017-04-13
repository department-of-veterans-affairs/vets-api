# frozen_string_literal: true
require 'common/client/base'
require 'hca/voa/configuration'
require 'hca/voa/enrollment_system'
require 'hca/service'

module HCA::VOA
  class Service < HCA::Service
    configuration HCA::VOA::Configuration

    def submit_form(form)
      formatted = HCA::VOA::EnrollmentSystem.veteran_to_save_submit_form(form, @current_user)
      content = Gyoku.xml(formatted)
      submission = client.build_request(:save_submit_form, message: content)
      response = post_submission(submission)
      root = response.body.locate('S:Envelope/S:Body/submitFormResponse').first
      {
        success: true,
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first.text
      }
    end

    def health_check
      submission = client.build_request(:get_form_submission_status, message:
        { formSubmissionId: Settings.hca.voa.healthcheck_id })
      response = post_submission(submission)
      root = response.body.locate('S:Envelope/S:Body/retrieveFormSubmissionStatusResponse').first
      {
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first.text
      }
    end

    private

    def client
      soap(namespace: 'http://va.gov/schema/esr/voa/v1',
           service_namespace: 'http://va.gov/service/esr/voa/v1')
    end
  end
end
