# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'
require 'va_1010_forms/service_utils'

module Form1010Ezr
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include VA1010Forms::ServiceUtils

    FORM_ID = '10-10EZ'

    # @param [Hash] user_identifier
    def initialize(user_identifier = nil)
      super()
      @user_identifier = user_identifier
    end

    # @param [HashWithIndifferentAccess] form JSON form data
    def submit_form(form)
      parsed_form = parsed_form(form)

      validate_form(parsed_form)

      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(parsed_form, @user_identifier)
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

    # Compare the 'parsed_form' to the form schema in vets-json-schema
    def validate_form(parsed_form)
      schema = VetsJsonSchema::SCHEMAS[FORM_ID]
      # @return [Array<String>] array of strings detailing schema validation failures
      validation_errors = JSON::Validator.fully_validate(schema, parsed_form)

      if validation_errors.any?
        failed_form_message = '1010EZR form validation failed. Form does not match schema.'

        Rails.logger.error(failed_form_message)
        raise StandardError, failed_form_message
      end
    end

    private

    def parsed_form(form)
      JSON.parse(form)
    end
  end
end
