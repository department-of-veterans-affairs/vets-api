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
      else
        # Fallback to Rails logger when Sentry is not configured
        log_message_to_rails(message, level, extra_context)
      end
    end

    def log_exception_to_sentry(exception, extra_context = {}, tags_context = {}, level = 'error')
      level = normalize_shared_level(level, exception)
      # https://docs.sentry.io/platforms/ruby/usage/set-level/
      # valid sentry levels: log, debug, info, warning, error, fatal
      level = 'warning' if level == 'warn'

      if Settings.sentry.dsn.present?
        set_sentry_metadata(extra_context, tags_context)
        Sentry.capture_exception(exception.cause.presence || exception, level:)
      else
        # Fallback to Rails logger when Sentry is not configured
        rails_level = level == 'warning' ? 'warn' : level
        message = "#{exception.message}."
        case rails_level
        when 'debug' then Rails.logger.debug(message)
        when 'info' then Rails.logger.info(message)
        when 'warn' then Rails.logger.warn(message)
        when 'fatal' then Rails.logger.fatal(message)
        else # 'error' and unknown levels
          Rails.logger.error(message)
        end
      end
    end

    def log_message_to_rails(message, level, extra_context = {})
      # this can be a drop-in replacement for now, but maybe suggest teams
      # handle extra context on their own and move to a direct Rails.logger call?
      #
      # Code was previously using Rails.logger.send(level, formatted_message) which could cause an exception
      # of its own. Hacky, but safe. Rails.logger.info etc do the right thing.

      # if level is passed as a symbol (e.g. :warn), handle it. convert to string

      level = level.to_s.downcase
      level = 'warn' if level == 'warning' # Rails doesn't support Sentries Warning level
      message = '[No Message Provided]' if message.blank?

      formatted_message = if extra_context.nil? || (extra_context.respond_to?(:empty?) && extra_context.empty?)
                            message
                          else
                            "#{message} : #{extra_context}"
                          end
      case level
      when 'debug'
        Rails.logger.debug(formatted_message)
      when 'info'
        Rails.logger.info(formatted_message)
      when 'warn'
        Rails.logger.warn(formatted_message)
      when 'fatal'
        Rails.logger.fatal(formatted_message)
      else # 'error' and unknown levels
        Rails.logger.error(formatted_message)
      end
    end

    def log_exception_to_rails(exception, level = 'error') # rubocop:disable Metrics/MethodLength
      level = level.to_s.downcase
      level = normalize_shared_level(level, exception)
      level = 'warn' if level == 'warning' # Rails doesn't support Sentries Warning level

      # Handle nil exception gracefully - log a placeholder message instead of crashing
      return log_message_to_rails('[No Exception Provided]', level) unless exception

      if exception.is_a? Common::Exceptions::BackendServiceException
        error_details = (Array(exception.errors).first&.try(:attributes) || {}).compact.reject do |_k, v|
          v.nil? || (v.respond_to?(:empty?) && v.empty?)
        end

        # Add backtrace to error_details - this is what the tests expect
        log_payload = error_details.merge(backtrace: exception.backtrace)

        case level
        when 'debug' then Rails.logger.debug(exception.message, log_payload)
        when 'info' then Rails.logger.info(exception.message, log_payload)
        when 'warn' then Rails.logger.warn(exception.message, log_payload)
        when 'fatal' then Rails.logger.fatal(exception.message, log_payload)
        else # 'error' and unknown levels
          Rails.logger.error(exception.message, log_payload)
        end
      else
        case level
        when 'debug' then Rails.logger.debug(exception)
        when 'info' then Rails.logger.info(exception)
        when 'warn' then Rails.logger.warn(exception)
        when 'fatal' then Rails.logger.fatal(exception)
        else # 'error' and unknown levels
          Rails.logger.error(exception)
        end
      end
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
