# frozen_string_literal: true

module Sentry
  module RescueEVSSErrors
    include SentryLogging

    private

    def rescue_evss_errors(keys)
      yield
    rescue EVSS::ErrorMiddleware::EVSSError => e
      if e.details.find { |m| keys.include?(m['key']) }
        log_exception_to_sentry(e, {}, {}, :warn)
        raise Sentry::IgnoredError, e.message
      end
      raise
    end
  end
end
