unless ENV['SENTRY_DSN']
  ENV['SENTRY_DSN'] = Settings.sentry.dsn
end
