# frozen_string_literal: true

module SharedRailsLogging
  extend ActiveSupport::Concern

  def log_message(message, level, extra_context = {})
    level = normalize_level(level, nil)
    formatted_message = extra_context.empty? ? message : "#{message} : #{extra_context}"
    rails_logger(level, formatted_message)
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
