module SentryLogging

  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    formatted_message = extra_context.empty? ? message : message + ' : ' + extra_context.to_s
    Rails.logger.send(level.to_sym, formatted_message)
    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) unless !extra_context.is_a?(Hash) || extra_context.empty?
      Raven.tags_context(tags_context) unless !tags_context.is_a?(Hash) || tags_context.empty?
      Raven.capture_message(message, level: level)
    end
  end

  def log_exception_to_sentry(exception)
    Raven.capture_exception(exception.cause.presence || exception) if Settings.sentry.dsn.present?
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end
end