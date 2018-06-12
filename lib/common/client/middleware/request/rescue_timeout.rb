# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Request
        # must be added right before http_client adapter
        class RescueTimeout < Faraday::Middleware
          include SentryLogging

          def initialize(app = nil, error_code = 'VA900', error_tags_context = {})
            @error_code = error_code
            @error_tags_context = error_tags_context
            super(app)
          end

          def call(env)
            @app.call(env)
          rescue Faraday::TimeoutError => e
            log_exception_to_sentry(e, {}, @error_tags_context, :warn)
            raise Common::Exceptions::BackendServiceException, @error_code
          end
        end
      end
    end
  end
end
