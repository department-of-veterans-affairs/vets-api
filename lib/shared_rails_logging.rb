# frozen_string_literal: true

module SharedRailsLogging
  extend ActiveSupport::Concern

  def log_message_to_rails(message, level, extra_context = {})
    # this can be a drop-in replacement for now, but maybe suggest teams
    # handle extra context on their own and move to a direct Rails.logger call?
    formatted_message = extra_context.empty? ? message : "#{message} : #{extra_context}"
    Rails.logger.send(level, formatted_message)
  end

  def log_exception_to_rails(exception, level = 'error')
    level = normalize_level(level, exception)
    if exception.is_a? Common::Exceptions::BackendServiceException
      error_details = exception.errors.first.attributes.compact.reject { |_k, v| v.try(:empty?) }
      log_message_to_rails(exception.message, level, error_details.merge(exception.backtrace))
    else
      log_message_to_rails("#{exception.message}.", level)
    end

    log_message_to_rails(exception.backtrace.join("\n"), level) unless exception.backtrace.nil?
  end

  def normalize_level(level, exception)
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
end
