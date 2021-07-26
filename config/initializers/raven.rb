# frozen_string_literal: true

require 'sentry/processor/email_sanitizer'
require 'sentry/processor/filter_request_body'
require 'sentry/processor/log_as_warning'
require 'sentry/processor/pii_sanitizer'

Rails.application.reloader.to_prepare do
  Raven.configure do |config|
    config.dsn = Settings.sentry.dsn if Settings.sentry.dsn
    config.current_environment = Settings.vsp_environment if Settings.vsp_environment

    # Raven defaults can be found at https://github.com/getsentry/raven-ruby/blob/master/lib/raven/configuration.rb
    ignored = config.excluded_exceptions.dup
    ignored.delete 'ActionController::InvalidAuthenticityToken'
    config.excluded_exceptions = ignored

    # filters emails from Sentry exceptions and log messsges
    config.processors << Sentry::Processor::EmailSanitizer
    config.processors << Sentry::Processor::PIISanitizer
    config.processors << Sentry::Processor::LogAsWarning
    config.processors << Sentry::Processor::FilterRequestBody

    config.async = lambda { |event|
      SentryJob.perform_async(event)
    }
  end
end
