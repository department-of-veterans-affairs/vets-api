# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'

module HCA
  class Service < Common::Client::Base
    TIMEOUT_KEY = 'api.hca.timeout'

    configuration HCA::Configuration

    def initialize(current_user = nil)
      @current_user = current_user
    end

    def submit_form(form)
      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(form, @current_user)
      content = Gyoku.xml(formatted)
      submission = soap.build_request(:save_submit_form, message: content)
      response = post_submission(submission)
      root = response.body.locate('S:Envelope/S:Body/submitFormResponse').first
      {
        success: true,
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first&.text || Time.now.getlocal.to_s
      }
    end

    def health_check
      submission = soap.build_request(:get_form_submission_status, message:
        { formSubmissionId: HCA::Configuration::HEALTH_CHECK_ID })
      response = post_submission(submission)
      root = response.body.locate('S:Envelope/S:Body/retrieveFormSubmissionStatusResponse').first
      {
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first&.text || Time.now.getlocal.to_s
      }
    end

    private

    def handle_timeout(e)
      StatsD.increment(TIMEOUT_KEY)
      log_exception_to_sentry(e, {}, {}, 'warning')
      raise Common::Exceptions::GatewayTimeout
    end

    def post_submission(submission)
      perform(:post, '', submission.body)
    rescue Common::Exceptions::GatewayTimeout => e
      handle_timeout(e)
    rescue Common::Client::Errors::HTTPError => e
      if e.code.to_s == '503'
        handle_timeout(e)
      else
        raise
      end
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
