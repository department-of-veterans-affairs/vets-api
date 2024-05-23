# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'
require 'hca/ezr_postfill'
require 'va1010_forms/utils'

module Form1010Ezr
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    include VA1010Forms::Utils
    include SentryLogging

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

    def submit_async(parsed_form)
      HCA::EzrSubmissionJob.perform_async(
        HealthCareApplication::LOCKBOX.encrypt(parsed_form.to_json),
        HealthCareApplication.get_user_identifier(@user)
      )

      { success: true, formSubmissionId: nil, timestamp: nil }
    end

    def submit_sync(parsed_form)
      res = with_monitoring do
        es_submit(parsed_form, FORM_ID)
      end

      # Log the 'formSubmissionId' for successful submissions
      Rails.logger.info("SubmissionID=#{res[:formSubmissionId]}")

      res
    end

    # @param [HashWithIndifferentAccess] parsed_form JSON form data
    def submit_form(parsed_form)
      # Log the 'veteranDateOfBirth' to ensure the frontend validation is working as intended
      # REMOVE THE FOLLOWING TWO LINES OF CODE ONCE THE DOB ISSUE HAS BEEN DIAGNOSED - 3/27/24
      @unprocessed_user_dob = parsed_form['veteranDateOfBirth'].clone
      parsed_form = configure_and_validate_form(parsed_form)

      if Flipper.enabled?(:ezr_async, @user)
        submit_async(parsed_form)
      else
        submit_sync(parsed_form)
      end
    rescue => e
      log_submission_failure(parsed_form)
      Rails.logger.error "10-10EZR form submission failed: #{e.message}"
      raise e
    end

    def log_submission_failure(parsed_form)
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.failed_wont_retry")

      if parsed_form.present?
        PersonalInformationLog.create!(
          data: parsed_form,
          error_class: 'Form1010Ezr FailedWontRetry'
        )

        log_message_to_sentry(
          '1010EZR total failure',
          :error,
          {
            first_initial: parsed_form['veteranFullName']['first'][0],
            middle_initial: parsed_form['veteranFullName']['middle'].try(:[], 0),
            last_initial: parsed_form['veteranFullName']['last'][0]
          },
          ezr: :total_failure
        )
      end
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

        log_validation_errors(parsed_form)

        Rails.logger.error(
          "10-10EZR form validation failed. Form does not match schema. Error list: #{validation_errors}"
        )
        raise Common::Exceptions::SchemaValidationErrors, validation_errors
      end
    end

    # Add required fields not included in the JSON schema, but are
    # required in the Enrollment System API
    def post_fill_required_fields(parsed_form)
      required_fields = HCA::EzrPostfill.post_fill_hash(@user)

      parsed_form.merge!(required_fields)
    end

    # Due to issues with receiving submissions that do not include the Veteran's DOB, we'll
    # try to add it in before we validate the form
    def post_fill_veteran_date_of_birth(parsed_form)
      return if parsed_form['veteranDateOfBirth'].present?

      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.missing_date_of_birth")

      parsed_form['veteranDateOfBirth'] = @user.birth_date
      parsed_form
    end

    # Due to issues with receiving submissions that do not include the Veteran's full name, we'll
    # try to add it in before we validate the form
    def post_fill_veteran_full_name(parsed_form)
      return if parsed_form['veteranFullName'].present?

      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.missing_full_name")

      parsed_form['veteranFullName'] = @user.full_name_normalized&.compact&.stringify_keys
      parsed_form
    end

    # Due to issues with receiving submissions that do not include the Veteran's SSN, we'll
    # try to add it in before we validate the form
    def post_fill_veteran_ssn(parsed_form)
      return if parsed_form['veteranSocialSecurityNumber'].present?

      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.missing_ssn")

      parsed_form['veteranSocialSecurityNumber'] = @user.ssn_normalized
      parsed_form
    end

    def post_fill_user_fields(parsed_form)
      post_fill_veteran_full_name(parsed_form)
      post_fill_veteran_date_of_birth(parsed_form)
      post_fill_veteran_ssn(parsed_form)
    end

    def post_fill_fields(parsed_form)
      post_fill_required_fields(parsed_form)
      post_fill_user_fields(parsed_form)

      parsed_form.compact
    end

    def configure_and_validate_form(parsed_form)
      post_fill_fields(parsed_form)
      validate_form(parsed_form)
      # Due to overriding the JSON form schema, we need to do so after the form has been validated
      override_parsed_form(parsed_form)
      add_financial_flag(parsed_form)
    end

    def add_financial_flag(parsed_form)
      if parsed_form['veteranGrossIncome'].present?
        parsed_form.merge('discloseFinancialInformation' => true)
      else
        parsed_form
      end
    end

    def log_validation_errors(parsed_form)
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.validation_error")

      PersonalInformationLog.create(
        data: parsed_form,
        error_class: 'Form1010Ezr ValidationError'
      )
    end
  end
end
