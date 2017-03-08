Raven.configure do |config|
  if Settings.sentry.dsn
    config.dsn = Settings.sentry.dsn
  end
end
