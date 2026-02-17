# frozen_string_literal: true

# Redacts PII from job args for logging. Runs first so SemanticLogging (and any
# error handlers) see filtered args. Restoring in ensure means the job payload
# is restored after the worker runs; the worker itself still receives filtered
# args during perform. If the worker must receive real args, redact only in the
# logging layer (e.g. custom JobLogger) instead of mutating job['args'].
class Sidekiq::FilterArgsMiddleware
  def call(worker, job, queue)
    original_args = job['args'].deep_dup
    job['args'] = filter_sensitive_args(job['class'], job['args'])

    Rails.logger.info "MIDDLEWARE - Filtered args: #{job['args'].inspect}"
    yield
  ensure
    job['args'] = original_args if original_args
  end

  private

  def filter_sensitive_args(job_class, args)
    args.map do |arg|
      case arg
      when Hash
        arg.except(:email, :first_name)
      when String
        arg.include?('email') || arg.include?('first_name') ? '[FILTERED]' : arg
      else
        arg
      end
    end
  end
end
