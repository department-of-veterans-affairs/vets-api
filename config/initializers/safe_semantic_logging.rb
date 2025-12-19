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
  # Note: We _could_ override error directly but this breaks RSpec spies on Rails.logger
  # def error(message = nil, payload = nil, &)
  #   if SafeSemanticLogging.safe_log_enabled? && payload.is_a?(Hash)
  #     ex = payload[:exception]
  #     payload = payload.merge(exception: RuntimeError.new(ex.to_s)) if ex && !ex.respond_to?(:backtrace)

  #     # Maybe worthwhile to see if coverage can help us here?
  #     # if Rails.env.test? && ex && !ex.is_a?(Exception)
  #     #   raise 'SafeSemanticLogging enabled - non-exception logged as exception'
  #     # end

  #     # Handle nil exception too
  #     payload = payload.merge(exception: RuntimeError.new('No exception provided')) if ex.nil?
  #   end
  #   super
  # end

  def log_internal(level, index, message, payload = nil, exception, &block)
    if SafeSemanticLogging.safe_log_enabled? && payload.is_a?(Hash)
      ex = payload[:exception]
      if ex && !ex.respond_to?(:backtrace)
        exception ||= RuntimeError.new(ex.to_s)
      elsif ex.nil?
        exception ||= RuntimeError.new('No exception provided')
      end
    end

    super(level, index, message, payload, exception, &block)
  end


  def self.safe_log_enabled?
    return false unless database_exists?

    Flipper.enabled?(:safe_semantic_logging)
  rescue => e
    Rails.logger.warn("SafeSemanticLogging: Error checking feature flag - #{e.message}")
    false
  end

  def self.database_exists?
    ActiveRecord::Base.connection
  rescue ActiveRecord::NoDatabaseError
    false
  else
    true
  end
end

Rails.logger.singleton_class.prepend(SafeSemanticLogging)
