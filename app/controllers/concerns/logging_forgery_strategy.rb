# frozen_string_literal: true

class LoggingForgeryStrategy
  include SentryLogging

  def initialize(controller)
    @controller = controller
  end

  def handle_unverified_request
    log_message_to_sentry(
      'Request susceptible to CSRF',
      :info,
      controller: @controller.controller_name,
      action: @controller.action_name
    )
  end
end
