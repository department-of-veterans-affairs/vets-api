# frozen_string_literal: true

require 'sentry/processor/email_sanitizer'
Raven.configure do |config|
  config.dsn = Settings.sentry.dsn if Settings.sentry.dsn

  # filters emails from Sentry exceptions and log messsges
  config.processors << Sentry::Processor::EmailSanitizer
  config.processors << Sentry::Processor::PIISanitizer
  config.processors << Sentry::Processor::LogAsWarning

  config.excluded_exceptions += ['Sentry::IgnoredError']

  config.before_send = lambda do |event, hint|
    return event unless hint[:exception] && hint[:exception].is_a?(Common::Exceptions::BackendServiceException)

    event.fingerprint = hint[:exception].key
    event.tags.merge!(key: hint[:exception].key)
    event
  end

  config.async = ->(event) { SentryJob.perform_async(event) }
end
