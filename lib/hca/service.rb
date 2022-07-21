# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'

module HCA
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.1010ez'

    configuration HCA::Configuration

    # @param [Hash] user_identifier
    def initialize(user_identifier = nil)
      @user_identifier = user_identifier
    end

    # @param [HashWithIndifferentAccess] form JSON form data
    def submit_form(form)
      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(form, @user_identifier)
      content = Gyoku.xml(formatted)
      submission = soap.build_request(:save_submit_form, message: content)

      is_short_form = HealthCareApplication.new(form: form.to_json).short_form?

      response = with_monitoring do
        perform(:post, '', submission.body)
      rescue => e
        increment_failure('submit_form_short_form', e) if is_short_form
        raise e
      ensure
        increment_total('submit_form_short_form') if is_short_form
      end

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
      response = with_monitoring do
        perform(:post, '', submission.body)
      end
      root = response.body.locate('S:Envelope/S:Body/retrieveFormSubmissionStatusResponse').first
      {
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first&.text || Time.now.getlocal.to_s
      }
    end

    private

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
