class Sidekiq::FilterArgsMiddleware
  SENSITIVE_KEYS = %i[email first_name].freeze

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
      else
        arg
      end
    end
  end
end