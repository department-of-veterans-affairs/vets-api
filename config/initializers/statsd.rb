# frozen_string_literal: true
host = Settings.statsd.host
port = Settings.statsd.port

StatsD.backend = if host.present? && port.present?
                   StatsD::Instrument::Backends::UDPBackend.new("#{host}:#{port}", :datadog)
                 else
                   StatsD::Instrument::Backends::LoggerBackend.new(Rails.logger)
                 end

# Initialize session controller metric counters at 0

StatsD.increment(V0::SessionsController::STATSD_LOGIN_TOTAL_KEY, 0)
StatsD.increment(V0::SessionsController::STATSD_LOGIN_FAILED_KEY, 0, tags: ['error:unknown'])

SAML::AuthFailHandler::KNOWN_ERRORS.each do |known_error|
  StatsD.increment(V0::SessionsController::STATSD_LOGIN_FAILED_KEY, 0, tags: ["error:#{known_error}"])
end
