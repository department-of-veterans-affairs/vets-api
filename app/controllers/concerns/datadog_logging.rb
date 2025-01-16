# frozen_string_literal: true

module DatadogLogging
  extend ActiveSupport::Concern

  private

  def log_to_datadog(context, message, stack_trace)
    if Flipper.enabled?(:virtual_agent_enable_datadog_logging, current_user)
      error_details = { message: message, backtrace: stack_trace }
      Rails.logger.error(context: context, error_details: error_details)
    end
  end
end
