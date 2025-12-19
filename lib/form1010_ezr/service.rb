# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'
require 'hca/ezr_postfill'
require 'hca/overrides_parser'
require 'va1010_forms/enrollment_system/service'
require 'form1010_ezr/veteran_enrollment_system/associations/service'
require 'vets/shared_logging'

module Form1010Ezr
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    extend Vets::SharedLogging

    STATSD_KEY_PREFIX = 'api.1010ezr'

    # Due to using the same endpoint as the 10-10EZ (HealthCareApplication), we
    # can utilize the same client configuration
    configuration HCA::Configuration

    FORM_ID = '10-10EZR'

    # @param [Object] user
    def initialize(user)
      super()
      @user = user
    end

    def self.veteran_initials(parsed_form)
      {
        first_initial: parsed_form.dig('veteranFullName', 'first')&.chr || 'no initial provided',
        middle_initial: parsed_form.dig('veteranFullName', 'middle')&.chr || 'no initial provided',
        last_initial: parsed_form.dig('veteranFullName', 'last')&.chr || 'no initial provided'
      }
    end

    def self.log_submission_failure(parsed_form, msg)
      log_message_to_rails(msg, :error, veteran_initials(parsed_form))
    end

    def submit_async(parsed_form)
      HCA::EzrSubmissionJob.perform_async(
        HealthCareApplication::LOCKBOX.encrypt(parsed_form.to_json),
        @user.uuid
      )

      { success: true, formSubmissionId: nil, timestamp: nil }
    end

    def submit_sync(parsed_form)
      res = with_monitoring do
        VA1010Forms::EnrollmentSystem::Service.new(
          HealthCareApplication.get_user_identifier(@user)
        ).submit(parsed_form, FORM_ID)
      end
      # Log the 'formSubmissionId' for successful submissions
      log_successful_submission(res[:formSubmissionId], self.class.veteran_initials(parsed_form))

      if parsed_form['attachments'].present?
        StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.submission_with_attachment")
      end

      res
    rescue => e
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.failed")
      Form1010Ezr::Service.log_submission_failure(parsed_form, '[10-10EZR] failure')
      raise e
    end

    # @param [HashWithIndifferentAccess] parsed_form JSON form data
    def submit_form(parsed_form)
      # Log the 'veteranDateOfBirth' to ensure the frontend validation is working as intended
      # REMOVE THE FOLLOWING TWO LINES OF CODE ONCE THE DOB ISSUE HAS BEEN DIAGNOSED - 3/27/24
      @unprocessed_user_dob = parsed_form['veteranDateOfBirth'].clone
      parsed_form = configure_and_validate_form(parsed_form)

      handle_associations(parsed_form) if Flipper.enabled?(:ezr_emergency_contacts_enabled, @user)

      submit_async(parsed_form)
    rescue => e
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.failed")
      self.class.log_submission_failure(parsed_form, '[10-10EZR] failure')
      raise e
    end

    private

    # Compare the 'parsed_form' to the JSON form schema in vets-json-schema
    def validate_form(parsed_form)
      schema = VetsJsonSchema::SCHEMAS[FORM_ID]
      # @return [Array<String>] array of strings detailing schema validation failures
      validation_errors = JSON::Validator.fully_validate(schema, parsed_form)

      if validation_errors.present?
        # REMOVE THE FOLLOWING SIX LINES OF CODE ONCE THE DOB ISSUE HAS BEEN DIAGNOSED - 3/27/24
        if validation_errors.find { |error| error.include?('veteranDateOfBirth') }.present?
          PersonalInformationLog.create!(
            data: @unprocessed_user_dob,
            error_class: "Form1010Ezr 'veteranDateOfBirth' schema failure"
          )
        end

        log_validation_errors(validation_errors, parsed_form)

        raise Common::Exceptions::SchemaValidationErrors, validation_errors
      end
    end

    # <---- Post-fill methods ---->
    # Add required fields not included in the JSON schema, but are
    # required in the Enrollment System API
    def post_fill_required_fields(parsed_form)
      required_fields = HCA::EzrPostfill.post_fill_hash(@user)

      parsed_form.merge!(required_fields)
    end

    # Due to issues with receiving submissions that do not include the Veteran's DOB, full name, SSN, and/or
    # gender, we'll try to add them in before we validate the form
    def post_fill_required_user_fields(parsed_form)
      # User fields that are required in the 10-10EZR schema, but not editable on the frontend
      required_user_form_fields = {
        'veteranDateOfBirth' => @user.birth_date,
        'veteranFullName' => @user.full_name_normalized&.compact&.stringify_keys,
        'veteranSocialSecurityNumber' => @user.ssn_normalized,
        'gender' => @user.gender
      }

      required_user_form_fields.each do |key, value|
        next if parsed_form[key].present?

        StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.missing_#{key.underscore}")

        parsed_form[key] = value
      end
    end

    def post_fill_fields(parsed_form)
      post_fill_required_fields(parsed_form)
      post_fill_required_user_fields(parsed_form)

      parsed_form.compact
    end

    def configure_and_validate_form(parsed_form)
      post_fill_fields(parsed_form)
      validate_form(parsed_form)
      # Due to overriding the JSON form schema, we need to do so after the form has been validated
      HCA::OverridesParser.new(parsed_form).override
      add_financial_flag(parsed_form)
    end

    def add_financial_flag(parsed_form)
      if parsed_form['veteranGrossIncome'].present?
        parsed_form.merge('discloseFinancialInformation' => true)
      else
        parsed_form
      end
    end

    # @param [Hash] errors
    def log_validation_errors(errors, parsed_form)
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.validation_error")

      Rails.logger.error(
        "10-10EZR form validation failed. Form does not match schema. Error list: #{errors}"
      )

      PersonalInformationLog.create(
        data: parsed_form,
        error_class: 'Form1010Ezr ValidationError'
      )
    end

    def log_successful_submission(submission_id, veteran_initials)
      Rails.logger.info(
        '1010EZR successfully submitted',
        submission_id:,
        veteran_initials:
      )
    end

    def handle_associations(parsed_form)
      PersonalInformationLog.create!(
        data: parsed_form,
        error_class: 'Form1010Ezr handle associations'
      )

      form_associations = parsed_form.fetch('nextOfKins', []) + parsed_form.fetch('emergencyContacts', [])

      Form1010Ezr::VeteranEnrollmentSystem::Associations::Service.new(@user).reconcile_and_update_associations(
        form_associations
      )
      # Since we are using the Associations API to update the associations, we'll remove the
      # 'nextOfKins' and 'emergencyContacts' from the parsed_form to prevent redundancy
      %w[nextOfKins emergencyContacts].each { |key| parsed_form.delete(key) }

      parsed_form
    end
  end
end
