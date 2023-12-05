# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Request
        # must be added right before http_client adapter
        class RemoveCookies < Faraday::Middleware
          def call(env)
            @app.client.cookie_manager = nil
            @app.call(env)
          end
        end
      end
    end
  end
end
