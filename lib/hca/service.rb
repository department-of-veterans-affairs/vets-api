# frozen_string_literal: true
require 'common/client/base'
require 'soap/middleware/request/headers'
require 'soap/middleware/response/parse'
require 'hca/enrollment_system'

module HCA
  class Service < Common::Client::Base
    configuration HCA::Configuration

    def submit_form(form)
      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(form)
      submission = soap.build_request(:save_submit_form, message: formatted)
      post_submission(submission)
    end

    def health_check
      submission = soap.build_request(:get_form_submission_status, message:
        { formSubmissionId: HCA::Configuration::HEALTH_CHECK_ID })
      response = post_submission(submission)
      root = response.body.locate('S:Envelope/S:Body/retrieveFormSubmissionStatusResponse').first
      {
        id: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first.text
      }
    end

    private

    def post_submission(submission)
      perform(:post, '', submission.body)
    end

    def soap
      # Savon *seems* like it should be setting these things correctly
      # from what the docs say. Our WSDL file is weird, maybe?
      Savon.client(wsdl: HCA::Configuration::WSDL,
                   env_namespace: :soap,
                   element_form_default: :qualified,
                   namespaces: {
                     'xmlns:tns': 'http://va.gov/service/esr/voa/v1'
                   },
                   namespace: 'http://va.gov/schema/esr/voa/v1')
    end
  end
end
