# frozen_string_literal: true

module Sentry
  module RescueEVSSErrors
    include SentryLogging

    private

    def rescue_evss_errors(keys)
      yield
    rescue EVSS::ErrorMiddleware::EVSSError => e
      if e.message&.match keys
        log_exception_to_sentry(e, {}, {}, :warn)
        raise Sentry::IgnoredError, e.message
      end
      raise
    end
  end
end
