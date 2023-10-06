# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'
require 'va_1010_forms/service_utils'

module Form1010EzrSubmission
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include VA1010Forms::ServiceUtils

    STATSD_KEY_PREFIX = 'api.1010ezr'

    configuration HCA::Configuration

    # @param [Hash] user_identifier
    def initialize(user_identifier = nil)
      super()
      @user_identifier = user_identifier
    end

    # @param [HashWithIndifferentAccess] form JSON form data
    def submit(form)
      # parsed_form = JSON.parse(form)
      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(form, @user_identifier)
      content = Gyoku.xml(formatted)
      submission = soap.build_request(:save_submit_form, message: content)

      response =
        with_monitoring do
          perform(:post, '', submission.body)
        rescue => e
          Rails.logger.error "Form1010EzrSubmission failed: #{e}"
          raise e
        end

      root = response.body.locate('S:Envelope/S:Body/submitFormResponse').first
      {
        success: true,
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first&.text || Time.now.getlocal.to_s
      }
    end
  end
end
