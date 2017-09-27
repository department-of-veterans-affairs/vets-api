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
StatsD.increment(V0::SessionsController::STATSD_LOGIN_NEW_USER_KEY, 0)

SAML::AuthFailHandler::KNOWN_ERRORS.each do |known_error|
  StatsD.increment(V0::SessionsController::STATSD_LOGIN_FAILED_KEY, 0, tags: ["error:#{known_error}"])
end

%w(success failure).each do |s|
  StatsD.increment(V0::SessionsController::STATSD_CALLBACK_KEY, 0, tags: ["status:#{s}", 'context:unknown'])
  V0::SessionsController::STATSD_CONTEXT_MAP.values.each do |ctx|
    StatsD.increment(V0::SessionsController::STATSD_CALLBACK_KEY, 0, tags: ["status:#{s}", "context:#{ctx}"])
  end
end

# init GiBillStatus stats to 0
StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_TOTAL_KEY, 0)
StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_FAIL_KEY, 0, tags: ['error:unknown'])
EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS.each do |_error_key, error_val|
  StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_FAIL_KEY, 0, tags: ["error:#{error_val}"])
end
