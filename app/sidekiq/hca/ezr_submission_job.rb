# frozen_string_literal: true

require 'hca/soap_parser'
require 'form1010_ezr/service'

module HCA
  class EzrSubmissionJob
    include Sidekiq::Job
    include SentryLogging
    VALIDATION_ERROR = HCA::SOAPParser::ValidationError

    sidekiq_options retry: 14

    def self.decrypt_form(encrypted_form)
      JSON.parse(HealthCareApplication::LOCKBOX.decrypt(encrypted_form))
    end

    def perform(encrypted_form, user_identifier)
      form = self.class.decrypt_form(encrypted_form)
      Form1010Ezr::Service.new(user_identifier).submit_sync(form)
    rescue VALIDATION_ERROR => e
      PersonalInformationLog.create!(data: { form: }, error_class: 'EzrValidationError')
      log_exception_to_sentry(e)
    end
  end
end
