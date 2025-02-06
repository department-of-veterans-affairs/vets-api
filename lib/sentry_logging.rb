# frozen_string_literal: true

require 'sentry_logging'

module SentryLogging
  extend self

  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    level = normalize_level(level, nil)

    if Settings.sentry.dsn.present?
      set_sentry_metadata(extra_context, tags_context)
      Sentry.capture_message(message, level:)
    end
  end

  def log_exception_to_sentry(exception, extra_context = {}, tags_context = {}, level = 'error')
    level = normalize_level(level, exception)

    if Settings.sentry.dsn.present?
      set_sentry_metadata(extra_context, tags_context)
      Sentry.capture_exception(exception.cause.presence || exception, level:)
    end
  end

  def normalize_level(level, exception)
    # https://docs.sentry.io/platforms/ruby/usage/set-level/
    # valid sentry levels: log, debug, info, warning, error, fatal
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

  def non_nil_hash?(h)
    h.is_a?(Hash) && !h.empty?
  end

  private

  def set_sentry_metadata(extra_context, tags_context)
    Sentry.set_extras(extra_context) if non_nil_hash?(extra_context)
    Sentry.set_tags(tags_context) if non_nil_hash?(tags_context)
  end
end
