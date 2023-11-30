# frozen_string_literal: true

require 'hca/soap_parser'
require 'form1010_ezr/service'

module HCA
  class EzrSubmissionJob
    include Sidekiq::Job
    include SentryLogging
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError

    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, _e|
      log_submission_failure(decrypt_form(msg['args'][0]))
    end

    def self.log_submission_failure(parsed_form)
      Form1010Ezr::Service.new(nil).log_submission_failure(parsed_form)
    end

    def self.decrypt_form(encrypted_form)
      JSON.parse(HealthCareApplication::LOCKBOX.decrypt(encrypted_form))
    end

    def log_retry
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.async.retries")
    end

    def perform(encrypted_form, user_identifier)
      parsed_form = self.class.decrypt_form(encrypted_form)
      Form1010Ezr::Service.new(user_identifier).submit_sync(parsed_form)
    rescue VALIDATION_ERROR => e
      self.class.log_submission_failure(parsed_form)
      log_exception_to_sentry(e)
    rescue
      log_retry
      raise
    end
  end
end
