class Sidekiq::FilterArgsMiddleware
  SENSITIVE_KEYS = %i[email first_name].freeze
  REDACTED = '[REDACTED]'.freeze

  # Filter a job hash in place so args never contain email/first_name (for logging / error handlers).
  def self.filter_job!(job)
    return unless job.is_a?(Hash) && job['args'].is_a?(Array)

    job['args'] = new.send(:filter_sensitive_args, job['class'], job['args'])
  end

  def call(worker, job, queue)
    job['args'] = filter_sensitive_args(job['class'], job['args'])
    yield
  end

  private

  def filter_sensitive_args(job_class, args)
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