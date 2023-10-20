# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'
require 'va_1010_forms/service_utils'

module Form1010Ezr
  class Service < Common::Client::Base
    include VA1010Forms::ServiceUtils

    # Due to using the same endpoint as the 10-10EZ (HealthCareApplication), we
    # can utilize the same client configuration
    configuration HCA::Configuration

    FORM_ID = '10-10EZR'

    # @param [Object] user
    def initialize(user)
      super()
      @user = user
    end

    # @param [HashWithIndifferentAccess] parsed_form JSON form data
    def submit_form(parsed_form)
      begin
        validate_form(parsed_form)

        formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(parsed_form, @user)
        content = Gyoku.xml(formatted)
        submission = soap.build_request(:save_submit_form, message: content)

        response = perform(:post, '', submission.body)
      rescue => e
        Rails.logger.error "10-10EZR form submission failed: #{e.message}"
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
        failed_form_message = '10-10EZR form validation failed. Form does not match schema.'

        Rails.logger.error(failed_form_message)
        raise StandardError, failed_form_message
      end
    end
  end
end
