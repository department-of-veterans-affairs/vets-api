# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Request
        # must be added right before http_client adapter
        class RescueTimeout < Faraday::Middleware
          include SentryLogging
          def call(env)
            @app.call(env)
          rescue Faraday::TimeoutError, Faraday::Error::TimeoutError => e
            log_exception_to_sentry(e, {}, {backend_service: :evss}, :warn)
            raise Common::Exceptions::BackendServiceException.new('EVSS502')
          end
        end
      end
    end
  end
end
