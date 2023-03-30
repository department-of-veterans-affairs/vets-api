# frozen_string_literal: true

require 'sentry_logging'

module SentryLogging
  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    level = normalize_level(level, nil)
    formatted_message = extra_context.empty? ? message : "#{message} : #{extra_context}"
    rails_logger(level, formatted_message)

    if Settings.sentry.dsn.present?
      set_raven_metadata(extra_context, tags_context)
      Raven.capture_message(message, level:)
    end
  end

  def log_exception_to_sentry(exception, extra_context = {}, tags_context = {}, level = 'error')
    level = normalize_level(level, exception)

    if Settings.sentry.dsn.present?
      set_raven_metadata(extra_context, tags_context)
      Raven.capture_exception(exception.cause.presence || exception, level:)
    end

    if exception.is_a? Common::Exceptions::BackendServiceException
      rails_logger(level, exception.message, exception.errors, exception.backtrace)
    else
      rails_logger(level, "#{exception.message}.")
    end
    rails_logger(level, exception.backtrace.join("\n")) unless exception.backtrace.nil?
  end

  def normalize_level(level, exception)
    # https://docs.sentry.io/clients/ruby/usage/
    # valid raven levels: debug, info, warning, error, fatal
    level = case exception
            when Pundit::NotAuthorizedError
              'info'
            when Common::Exceptions::BaseError
              exception.sentry_type.to_s
            else
              level.to_s
            end

    return 'warning' if level == 'warn'

    level
  end

  def rails_logger(level, message, errors = nil, backtrace = nil)
    # rails logger uses 'warn' instead of 'warning'
    level = 'warn' if level == 'warning'
    if errors.present?
      error_details = errors.first.attributes.compact.reject { |_k, v| v.try(:empty?) }
      Rails.logger.send(level, message, error_details.merge(backtrace:))
    else
      Rails.logger.send(level, message)
    end
  end

  def non_nil_hash?(h)
    h.is_a?(Hash) && !h.empty?
  end

  private

  def set_raven_metadata(extra_context, tags_context)
    Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
    Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
  end
end
