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
      # Normalizes and safely logs a message to Rails.logger.
      # Corner cases handled:
      #  - level nil / invalid / symbol -> coerced & defaulted to 'warn'
      #  - message nil or blank -> "[No Message]"
      #  - extra_context nil / non-hash / empty -> omitted
      #  - only allowed levels: debug, info, warn, error, fatal

      allowed_levels = %w[debug info warn error fatal].freeze
      normalized_level = level.to_s
      normalized_level = 'warn' unless allowed_levels.include?(normalized_level)

      safe_message = message.to_s.strip
      safe_message = '[No Message]' if safe_message.empty?

      context_suffix = extra_context.is_a?(Hash) && !extra_context.empty? ? " : #{extra_context}" : ''

      final_line = safe_message + context_suffix
      Rails.logger.public_send(normalized_level, final_line)
    end

    def log_exception_to_rails(exception, level = 'error')
      # Corner cases handled:
      #  - nil exception => single warn line
      #  - BackendServiceException => include extracted error details (no backtrace in context)
      #  - generic exceptions => message line + backtrace line
      #  - backtrace logged only once
      if exception.nil?
        log_message_to_rails('[Nil Exception]', 'warn')
        return
      end

      allowed_levels = %w[debug info warn error fatal].freeze
      level = normalize_shared_level(level, exception)
      level = 'error' unless allowed_levels.include?(level)

      if exception.is_a?(Common::Exceptions::BackendServiceException)
        # Extract non-empty error attributes for context (excluding backtrace to prevent duplication)
        error_details = exception.errors.first.attributes.compact.reject { |_k, v| v.respond_to?(:empty?) && v.empty? }
        log_message_to_rails(exception.message.to_s, level, error_details)
      else
        msg = exception.message.to_s.strip
        msg = '[No Message]' if msg.empty?
        log_message_to_rails("#{msg}.", level)
      end

      bt = exception.backtrace
      log_message_to_rails(bt.join("\n"), level) if bt.present?
    end

    def normalize_shared_level(level, exception)
      case exception
      when Pundit::NotAuthorizedError
        'info'
      when Common::Exceptions::BaseError
        # could change this attribute to log_level
        # to make clear it is not just a Sentry concern
        exception.sentry_type.to_s
      else
        level.to_s
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
