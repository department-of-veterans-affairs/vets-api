# frozen_string_literal: true
Raven.configure do |config|
  config.dsn = Settings.sentry.dsn if Settings.sentry.dsn
end
