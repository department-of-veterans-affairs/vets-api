# frozen_string_literal: true

module RandomFile
  extend ActiveSupport::Concern
  pp 'LOADING RANDOM THINGY'

  def log_message(message, level, extra_context = {}, _tags_context = {})
    level = normalize_level(level, nil)
    formatted_message = extra_context.empty? ? message : "#{message} : #{extra_context}"
    rails_logger(level, formatted_message)
  end

  def log_exception(exception, level = 'error')
    level = normalize_level(level, exception)

    if exception.is_a? Common::Exceptions::BackendServiceException
      rails_logger(level, exception.message, exception.errors, exception.backtrace)
    else
      rails_logger(level, "#{exception.message}.")
    end
    rails_logger(level, exception.backtrace.join("\n")) unless exception.backtrace.nil?
  end

  def normalize_level(level, exception)
    level = case exception
            when Pundit::NotAuthorizedError
              'info'
            else
              level.to_s
            end

    return 'warn' if level == 'warning'

    level
  end

  def rails_logger(level, message, errors = nil, backtrace = nil)
    if errors.present?
      error_details = errors.first.attributes.compact.reject { |_k, v| v.try(:empty?) }
      Rails.logger.send(level, message, error_details.merge(backtrace:))
    else
      Rails.logger.send(level, message)
    end
  end
end
