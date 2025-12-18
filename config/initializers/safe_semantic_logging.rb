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
  def error(message = nil, payload = nil, &)
    if payload.is_a?(Hash)
      ex = payload[:exception]
      payload = payload.merge(exception: RuntimeError.new(ex.to_s)) if ex && !ex.respond_to?(:backtrace)
    end
    super
  end
end

Rails.logger.singleton_class.prepend(SafeSemanticLogging)
