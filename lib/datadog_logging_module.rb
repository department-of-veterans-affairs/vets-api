module DatadogLoggingModule
  def datadog_logging_module(context, message, stack_trace)
    if Flipper.enabled?(:virtual_agent_enable_datadog_logging, current_user)
      error_details = { message: message, backtrace: stack_trace }
      Rails.logger.error(context, error_details)
    end
  end
end