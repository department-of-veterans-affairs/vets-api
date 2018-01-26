# frozen_string_literal: true

module SentryLogging
  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    formatted_message = extra_context.empty? ? message : message + ' : ' + extra_context.to_s
    Rails.logger.send(level.to_sym, formatted_message)
    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
      Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
      Raven.capture_message(message, level: level)
    end
  end

  def log_exception_to_sentry(exception, extra_context = {}, tags_context = {})
    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
      Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
      Raven.capture_exception(exception.cause.presence || exception)
    end
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end

  def non_nil_hash?(h)
    h.is_a?(Hash) && !h.empty?
  end
end
