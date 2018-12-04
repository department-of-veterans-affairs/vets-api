# frozen_string_literal: true

require 'common/client/concerns/handle_timeout'

module Common
  module Client
    module Middleware
      module Request
        class RescueTimeout < Faraday::Middleware
          include Common::Client::Middleware::HandleTimeout

          def initialize(app = nil, error_tags_context = {}, timeout_key = nil)
            @error_tags_context = error_tags_context
            @timeout_key = timeout_key
            super(app)
          end

          def call(env)
            @app.call(env)
          rescue Faraday::TimeoutError, HTTPClient::ReceiveTimeoutError,
                 EVSS::ErrorMiddleware::EVSSBackendServiceError, Timeout::Error => e
            handle_timeout(e)
          end
        end
      end
    end
  end
end
