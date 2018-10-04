# frozen_string_literal: true

require 'services/sso_service'

host = Settings.statsd.host
port = Settings.statsd.port

StatsD.backend = if host.present? && port.present?
                   StatsD::Instrument::Backends::UDPBackend.new("#{host}:#{port}", :datadog)
                 else
                   StatsD::Instrument::Backends::LoggerBackend.new(Rails.logger)
                 end

# Initialize session controller metric counters at 0

StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_TOTAL_KEY, 0)
StatsD.increment(V0::SessionsController::STATSD_LOGIN_NEW_USER_KEY, 0)

SAML::AuthFailHandler::KNOWN_ERRORS.each do |known_error|
  StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_FAILED_KEY, 0, tags: ["error:#{known_error}"])
end
StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_FAILED_KEY, 0, tags: ['error:multiple'])
StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_FAILED_KEY, 0, tags: ['error:unknown'])
StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_FAILED_KEY, 0, tags: ['error:validations_failed'])

%w[success failure].each do |s|
  StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_KEY, 0, tags: ["status:#{s}", 'context:unknown'])
  V0::SessionsController::STATSD_CONTEXT_MAP.each_value do |ctx|
    StatsD.increment(V0::SessionsController::STATSD_SSO_CALLBACK_KEY, 0, tags: ["status:#{s}", "context:#{ctx}"])
  end
end

# init GiBillStatus stats to 0
StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_TOTAL_KEY, 0)
StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_FAIL_KEY, 0, tags: ['error:unknown'])
StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_FAIL_KEY, 0, tags: ['error:scheduled_downtime'])
EVSS::GiBillStatus::GiBillStatusResponse::KNOWN_ERRORS.each_value do |error_val|
  StatsD.increment(V0::Post911GIBillStatusesController::STATSD_GI_BILL_FAIL_KEY, 0, tags: ["error:#{error_val}"])
end

# init letters/pciu address
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_letters.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_letters.fail", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_letter_beneficiary.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_letter_beneficiary.fail", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_countries.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_countries.fail", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_states.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_states.fail", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_address.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.get_address.fail", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.update_address.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.update_address.fail", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.policy.success", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.policy.failure", 0)

# disability compenstation submissions
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.submit_form526.total", 0)
StatsD.increment("#{EVSS::Service::STATSD_KEY_PREFIX}.submit_form526.fail", 0)
StatsD.increment("#{EVSS::DisabilityCompensationForm::SubmitForm526::STATSD_KEY_PREFIX}.try", 0)
StatsD.increment("#{EVSS::DisabilityCompensationForm::SubmitForm526::STATSD_KEY_PREFIX}.success", 0)
StatsD.increment("#{EVSS::DisabilityCompensationForm::SubmitForm526::STATSD_KEY_PREFIX}.retryable_error", 0)
StatsD.increment("#{EVSS::DisabilityCompensationForm::SubmitForm526::STATSD_KEY_PREFIX}.non_retryable_error", 0)
StatsD.increment("#{EVSS::DisabilityCompensationForm::SubmitForm526::STATSD_KEY_PREFIX}.exhausted", 0)

# init appeals
StatsD.increment("#{Appeals::Service::STATSD_KEY_PREFIX}.get_appeals.total", 0)
StatsD.increment("#{Appeals::Service::STATSD_KEY_PREFIX}.get_appeals.fail", 0)

# init  mvi
StatsD.increment("#{MVI::Service::STATSD_KEY_PREFIX}.find_profile.total", 0)
StatsD.increment("#{MVI::Service::STATSD_KEY_PREFIX}.find_profile.fail", 0)

# init Vet360
Vet360::Exceptions::Parser.instance.known_keys.each do |key|
  StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.exceptions", 0, tags: ["exception:#{key}"])
end
StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.total_operations", 0)
StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.posts_and_puts.success", 0)
StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.posts_and_puts.failure", 0)
StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.init_vet360_id.success", 0)
StatsD.increment("#{Vet360::Service::STATSD_KEY_PREFIX}.init_vet360_id.failure", 0)

# init eMIS
StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", 0, tags: ['present:true', 'present:false'])
StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.service_history", 0, tags: ['present:true', 'present:false'])

# init CentralMail
StatsD.increment("#{CentralMail::Service::STATSD_KEY_PREFIX}.upload.total", 0)
StatsD.increment("#{CentralMail::Service::STATSD_KEY_PREFIX}.upload.fail", 0)

# init SentryJob error monitoring
StatsD.increment(SentryJob::STATSD_ERROR_KEY, 0)
