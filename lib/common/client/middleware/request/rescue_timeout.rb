# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Request
        class RescueTimeout < Faraday::Middleware
          include SentryLogging

          def initialize(app = nil, error_tags_context = {})
            @error_tags_context = error_tags_context
            super(app)
          end

          def call(env)
            @app.call(env)
          rescue Faraday::TimeoutError, Net::ReadTimeout,
                 HTTPClient::ReceiveTimeoutError, Net::OpenTimeout,
                 EVSS::ErrorMiddleware::EVSSBackendServiceError => e
            log_exception_to_sentry(e, {}, @error_tags_context, :warn)
            raise Common::Exceptions::SentryIgnoredGatewayTimeout
          end
        end
      end
    end
  end
end
