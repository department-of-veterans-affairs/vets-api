# frozen_string_literal: true

require 'hca/soap_parser'
require 'form1010_ezr/service'

module HCA
  class EzrSubmissionJob
    include Sidekiq::Job
    extend SentryLogging
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError
    STATSD_KEY_PREFIX = 'api.1010ezr'
    DD_ZSF_TAGS = [
      'service:healthcare-application',
      'function: 10-10EZR async form submission'
    ].freeze

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

        log_message_to_sentry(
          '1010EZR total failure',
          :error,
          Form1010Ezr::Service.new(nil).veteran_initials(parsed_form),
          ezr: :total_failure
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
        api_key
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.submission_failure_email_sent")
      StatsD.increment('silent_failure_avoided_no_confirmation', tags: DD_ZSF_TAGS)
    end

    def perform(encrypted_form, user_uuid)
      user = User.find(user_uuid)
      parsed_form = self.class.decrypt_form(encrypted_form)

      Form1010Ezr::Service.new(user).submit_sync(parsed_form)
    rescue VALIDATION_ERROR => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.enrollment_system_validation_error")
      Form1010Ezr::Service.new(nil).log_submission_failure(parsed_form)
      self.class.log_exception_to_sentry(e)
      self.class.send_failure_email(parsed_form) if Flipper.enabled?(:ezr_use_va_notify_on_submission_failure)
    rescue
      StatsD.increment("#{STATSD_KEY_PREFIX}.async.retries")
      raise
    end
  end
end
