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
      #
      # Code was previously using Rails.logger.send(level, formatted_message) which could cause an exception
      # of its own. Hacky, but safe. Rails.logger.info etc do the right thing.

      # if level is passed as a symbol (e.g. :warn), handle it. convert to string

      level = level.to_s.downcase
      level = 'warn' if level == 'warning' # Rails doesn't support Sentries Warning level
      message = '[No Message Provided]' if message.blank?

      formatted_message = extra_context.empty? ? message : "#{message} : #{extra_context}"
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
      return log_message_to_rails('[No Exception Provided]', 'error') unless exception

      if exception.is_a? Common::Exceptions::BackendServiceException
        error_details = (Array(exception.errors).first&.try(:attributes) || {}).compact.reject do |_k, v|
          v.respond_to?(:empty?) && v.empty?
        end
        log_message_to_rails(exception.message, level, error_details.merge(backtrace: exception.backtrace))
      else
        case level
        when 'debug'
          Rails.logger.debug(exception)
        when 'info'
          Rails.logger.info(exception)
        when 'warn'
          Rails.logger.warn(exception)
        when 'fatal'
          Rails.logger.fatal(exception)
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
