# frozen_string_literal: true

# If the job raises an exception, Sidekiq sends the job payload to our error handlers (and to Sentry). We call
# filter_job! on that payload so the error report never contains real emails or names.
# 
# More specifically, this is a Sidekiq server middleware that scrubs sensitive personal data from job arguments
# before they are processed, ensuring that pii fields never appear in logs, 
# error trackers (e.g. Sentry), or any other observability tooling.
#
# Sensitive keys are defined in SENSITIVE_KEYS and are stripped from any Hash arguments.
# String arguments that appear to be email addresses (detected via '@') are replaced
# with a [REDACTED] placeholder.
#
# == Usage
#
# Register in your Sidekiq initializer so it wraps every job on the server side:

#   Sidekiq.configure_server do |config|
#     config.server_middleware do |chain|
#       chain.add Sidekiq::FilterArgsMiddleware
#     end
#   end
#
# For one-off filtering of a job hash (e.g. in error_handlers so exception
# context sent to Sentry or other handlers does not contain PII), use:
#   Sidekiq::FilterArgsMiddleware.filter_job!(job)
class Sidekiq::FilterArgsMiddleware
  SENSITIVE_KEYS = %i[email first_name].freeze
  REDACTED = '[REDACTED]'

  # Filter a job hash in place so args never contain email/first_name (for logging / error handlers).
  def self.filter_job!(job)
    return unless job.is_a?(Hash) && job['args'].is_a?(Array)

    job['args'] = new.send(:filter_sensitive_args, job['class'], job['args'])
  end

  def call(_worker, job, _queue)
    job['args'] = filter_sensitive_args(job['class'], job['args'])
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
