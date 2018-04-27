# frozen_string_literal: true

module SentryLogging
  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    level = normalize_level(level)
    formatted_message = extra_context.empty? ? message : message + ' : ' + extra_context.to_s
    rails_logger(level, formatted_message)
    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
      Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
      Raven.capture_message(message, level: level)
    end
  end

  def log_exception_to_sentry(
    exception,
    extra_context = {},
    tags_context = {},
    level = 'error'
  )
    level = normalize_level(level)
    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
      Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
      Raven.capture_exception(exception.cause.presence || exception, level: level)
    end
    rails_logger(level, "#{exception.message}.")
    rails_logger(level, exception.backtrace.join("\n")) unless exception.backtrace.nil?
  end

  def normalize_level(level)
    # https://docs.sentry.io/clients/ruby/usage/
    # valid raven levels: debug, info, warning, error, fatal
    level = level.to_s
    return 'warning' if level == 'warn'
    level
  end

  def rails_logger(level, message)
    # rails logger uses 'warn' instead of 'warning'
    level = 'warn' if level == 'warning'
    Rails.logger.send(level, message)
  end

  def non_nil_hash?(h)
    h.is_a?(Hash) && !h.empty?
  end
end
