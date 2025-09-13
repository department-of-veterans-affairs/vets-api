# frozen_string_literal: true

module Vets
  module SharedLogging
    extend ActiveSupport::Concern

    def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
      level = normalize_shared_level(level, nil)
      # https://docs.sentry.io/platforms/ruby/usage/set-level/
      # valid sentry levels: log, debug, info, warning, error, fatal
      level = 'warning' if level == 'warn'

      if Settings.sentry.dsn.present?
        set_sentry_metadata(extra_context, tags_context)
        Sentry.capture_message(message, level:)
      end
    end

    def log_exception_to_sentry(exception, extra_context = {}, tags_context = {}, level = 'error')
      level = normalize_shared_level(level, exception)

      if Settings.sentry.dsn.present?
        set_sentry_metadata(extra_context, tags_context)
        Sentry.capture_exception(exception.cause.presence || exception, level:)
      end
    end

    def log_message_to_rails(message, level, extra_context = {})
      # this can be a drop-in replacement for now, but maybe suggest teams
      # handle extra context on their own and move to a direct Rails.logger call?
      # guards against nil messages to avoid logging itself throwing exceptions.
      message = '[No message provided]' if message.nil?

      # Normalize and validate level (accept symbols / strings / nil)
      level = level.to_s if level
      level = 'warn' unless %w[info warn error].include?(level)
      if non_nil_hash?(extra_context)
        # Pass structured context as separate argument for semantic logger
        Rails.logger.send(level, message, extra_context)
      else
        Rails.logger.send(level, message)
      end
    end

    def log_exception_to_rails(exception, level = 'error')
      level = normalize_shared_level(level, exception)
      # Validate that level is one of the supported Rails logger methods
      level = if %w[info warn error].include?(level)
                level
              else
                (exception ? 'error' : 'warn')
              end

      # If level is error, use logging once and don't append backtrace to message
      # guards against nil exceptions!
      if exception.nil?
        Rails.logger.warn('[No Exception provided]')
      else
        Rails.logger.send(level, exception)
      end
    end

    def normalize_shared_level(level, exception)
      # If explicit level supplied (not nil), honor it directly
      return level.to_s if level

      case exception
      when Pundit::NotAuthorizedError
        'info'
      when Common::Exceptions::BaseError
        exception.sentry_type.to_s
      else
        'error'
      end
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
end
