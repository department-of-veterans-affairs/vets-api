# frozen_string_literal: true

# Patch SemanticLogger to handle non-exception 'exception' values gracefully
#
# When logging with SemanticLogger, it's possible that the :exception key in the
# log payload may contain a String or other non-exception object. This can lead to
# logging failures since SemanticLogger expects an Exception object with a
# backtrace method.
#
# This monkey-patch prevents logging failures when a String or other non-exception object
# is passed as the :exception key in log payloads
module SafeSemanticLogging
  # NOTE: We _could_ override error directly but this breaks RSpec spies on Rails.logger
  def log_internal(level, index, message = nil, payload = nil, exception = nil, &)
    if SafeSemanticLogging.safe_log_enabled?
      # Handle exception passed as third positional argument
      exception = RuntimeError.new(exception.to_s) if exception.present? && !exception.respond_to?(:backtrace)

      # Handle exception inside payload hash
      if payload.present? && payload.is_a?(Hash)
        ex = payload[:exception]
        if ex && !ex.respond_to?(:backtrace)
          payload = payload.dup
          payload[:exception] = RuntimeError.new(ex.to_s)
        end
      end
    end

    super(level, index, message, payload, exception, &)
  end

  def self.safe_log_enabled? = true
end

Rails.logger.singleton_class.prepend(SafeSemanticLogging)
