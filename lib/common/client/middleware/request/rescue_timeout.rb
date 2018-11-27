# frozen_string_literal: true

require 'sentry_logging'

module Common
  module Client
    module Middleware
      module Request
        class RescueTimeout < Faraday::Middleware
          include SentryLogging

          def initialize(app = nil, error_tags_context = {}, timeout_key = nil)
            @error_tags_context = error_tags_context
            @timeout_key = timeout_key
            super(app)
          end

          def call(env)
            @app.call(env)
          rescue Faraday::TimeoutError, HTTPClient::ReceiveTimeoutError,
                 EVSS::ErrorMiddleware::EVSSBackendServiceError, Timeout::Error => error
            StatsD.increment(@timeout_key) if @timeout_key
            log_exception_to_sentry(error, {}, @error_tags_context, :warn)
            raise Common::Exceptions::SentryIgnoredGatewayTimeout
          end
        end
      end
    end
  end
end
