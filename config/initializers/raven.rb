# frozen_string_literal: true

require 'sentry/processor/email_sanitizer'
Raven.configure do |config|
  config.dsn = Settings.sentry.dsn if Settings.sentry.dsn

  # filters emails from Sentry exceptions and log messsges
  config.processors << Sentry::Processor::EmailSanitizer
  config.processors << Sentry::Processor::PIISanitizer
end
