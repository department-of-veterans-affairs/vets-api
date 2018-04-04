# frozen_string_literal: true

module Sentry
  module RescueEVSSErrors
    private

    def rescue_evss_errors
      yield
    rescue EVSS::ErrorMiddleware::EVSSError => e
      log_message_to_sentry(e, :warn)
      raise Sentry::IgnoredError, e.message
    end
  end
end
