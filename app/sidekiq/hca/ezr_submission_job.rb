# frozen_string_literal: true

require 'hca/soap_parser'
require 'form1010_ezr/service'

module HCA
  class EzrSubmissionJob
    include Sidekiq::Job
    include SentryLogging
    include Common::Client::Concerns::Monitoring
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError

    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, _e|
      parsed_form = decrypt_form(msg['args'][0])

      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.failed_wont_retry")

      if parsed_form.present?
        PersonalInformationLog.create!(
          data: parsed_form,
          error_class: 'Form1010Ezr FailedWontRetry'
        )

        new.log_message_to_sentry(
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

    def perform(encrypted_form, user_uuid)
      user = User.find(user_uuid)
      parsed_form = self.class.decrypt_form(encrypted_form)

      Form1010Ezr::Service.new(user).submit_sync(parsed_form)
    rescue VALIDATION_ERROR => e
      Form1010Ezr::Service.new(nil).log_submission_failure(parsed_form)
      log_exception_to_sentry(e)
    rescue
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.async.retries")
      raise
    end
  end
end
