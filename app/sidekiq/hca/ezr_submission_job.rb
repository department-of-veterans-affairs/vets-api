# frozen_string_literal: true

require 'hca/soap_parser'
require 'form1010_ezr/service'

module HCA
  class EzrSubmissionJob
    include Sidekiq::Job
    extend SentryLogging

    FORM_ID = '10-10EZR'
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError
    STATSD_KEY_PREFIX = 'api.1010ezr'
    DD_ZSF_TAGS = {
      service: 'healthcare-application',
      function: '10-10EZR async form submission'
    }.freeze

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16

    sidekiq_retries_exhausted do |msg, _e|
      parsed_form = decrypt_form(msg['args'][0])

      StatsD.increment("#{STATSD_KEY_PREFIX}.failed_wont_retry")

      if parsed_form.present?
        PersonalInformationLog.create!(
          data: parsed_form,
          error_class: 'Form1010Ezr FailedWontRetry'
        )

        send_failure_email(parsed_form) if Flipper.enabled?(:ezr_use_va_notify_on_submission_failure)

        Form1010Ezr::Service.log_submission_failure_to_sentry(
          parsed_form,
          '1010EZR total failure',
          'total_failure'
        )
      end
    end

    def self.decrypt_form(encrypted_form)
      JSON.parse(HealthCareApplication::LOCKBOX.decrypt(encrypted_form))
    end

    def self.send_failure_email(parsed_form)
      email = parsed_form['email']
      return if email.blank?

      first_name = parsed_form.dig('veteranFullName', 'first')
      template_id = Settings.vanotify.services.health_apps_1010.template_id.form1010_ezr_failure_email
      api_key = Settings.vanotify.services.health_apps_1010.api_key
      salutation = first_name ? "Dear #{first_name}," : ''

      VANotify::EmailJob.perform_async(
        email,
        template_id,
        { 'salutation' => salutation },
        api_key,
        {
          callback_metadata: { notification_type: 'error', form_number: FORM_ID, statsd_tags: DD_ZSF_TAGS }
        }
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.submission_failure_email_sent")
    end

    def perform(encrypted_form, user_uuid)
      user = User.find(user_uuid)
      parsed_form = self.class.decrypt_form(encrypted_form)

      Form1010Ezr::Service.new(user).submit_sync(parsed_form)
    rescue VALIDATION_ERROR => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.enrollment_system_validation_error")

      PersonalInformationLog.create!(data: parsed_form, error_class: 'Form1010Ezr EnrollmentSystemValidationFailure')

      Form1010Ezr::Service.log_submission_failure_to_sentry(parsed_form, '1010EZR failure', 'failure')
      self.class.log_exception_to_sentry(e)
      self.class.send_failure_email(parsed_form) if Flipper.enabled?(:ezr_use_va_notify_on_submission_failure)
    rescue Ox::ParseError => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.failed_did_not_retry")

      Rails.logger.info("Form1010Ezr FailedDidNotRetry: #{e.message}")

      self.class.send_failure_email(parsed_form) if Flipper.enabled?(:ezr_use_va_notify_on_submission_failure)

      Form1010Ezr::Service.log_submission_failure_to_sentry(
        parsed_form, '1010EZR failure did not retry', 'failure_did_not_retry'
      )
      # The Sidekiq::JobRetry::Skip error will fail the job and not retry it
      raise Sidekiq::JobRetry::Skip
    rescue
      StatsD.increment("#{STATSD_KEY_PREFIX}.async.retries")
      raise
    end
  end
end
