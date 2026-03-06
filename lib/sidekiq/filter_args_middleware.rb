# frozen_string_literal: true

# Sidekiq server middleware that scrubs sensitive personal data from job arguments
# for jobs that are known to carry PII. Only jobs whose class is listed in
# PII_REDACT_JOB_CLASSES are filtered; all other jobs pass through untouched.
#
# This ensures PII never appears in logs, error trackers (e.g. Sentry), or any
# other observability tooling, regardless of how a job fails or is inspected.
#
# Filtering strategy:
# - Hash args: sensitive keys (see SENSITIVE_KEYS) are stripped entirely.
# - String args: anything containing '@' (i.e. an email address) is replaced with [REDACTED].
#
# == Adding a new PII-carrying job
#
# Add its class name to PII_REDACT_JOB_CLASSES. Both the middleware and the
# error handler (see config/initializers/sidekiq.rb) will then redact its args
# automatically.
#
# == Usage
#
# Register in your Sidekiq initializer so it wraps every job on the server side:
#
#   Sidekiq.configure_server do |config|
#     config.server_middleware do |chain|
#       chain.add Sidekiq::FilterArgsMiddleware
#     end
#   end
#
# For one-off filtering of a job hash (e.g. in error_handlers so exception
# context sent to Sentry or other handlers does not contain PII), use:
#
#   Sidekiq::FilterArgsMiddleware.filter_job!(job)
class Sidekiq::FilterArgsMiddleware
  SENSITIVE_KEYS = %i[email first_name].freeze
  REDACTED = '[REDACTED]'

  # Job classes whose args may contain PII; we redact in the middleware and in error_handlers.
  # Currently only used for dispute_debts (Form 5655). FSR could be added but has not been yet.
  PII_REDACT_JOB_CLASSES = [
    'DebtManagementCenter::VANotifyEmailJob',
    'DebtsApi::V0::Form5655::SendConfirmationEmailJob'
  ].freeze

  # Filter a job hash in place so args never contain email/first_name (for logging / error handlers).
  def self.filter_job!(job)
    return unless job.is_a?(Hash) && job['args'].is_a?(Array)

    job['args'] = new.send(:filter_sensitive_args, job['class'], job['args'])
  end

  def call(_worker, job, _queue)
    job['args'] = filter_sensitive_args(job['class'], job['args']) if PII_REDACT_JOB_CLASSES.include?(job['class'].to_s)
    yield
  end

  private

  def filter_sensitive_args(_job_class, args)
    args.map do |arg|
      case arg
      when Hash
        arg.deep_symbolize_keys.except(*SENSITIVE_KEYS)
      when String
        arg.include?('@') ? REDACTED : arg
      else
        arg
      end
    end
  end
end
