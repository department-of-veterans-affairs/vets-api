# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class RescueTimeout < Faraday::Response::Middleware
          include Common::Client::Middleware::HandleTimeout

          def initialize(app = nil, error_tags_context = {}, timeout_key = nil)
            @error_tags_context = error_tags_context
            @timeout_key = timeout_key
            super(app)
          end

          def on_complete(env)
            if env.status.to_i == 503
              @extra_context = { env_body: env.body }
              handle_timeout(Common::Exceptions::GatewayTimeout.new)
            end
          end
        end
      end
    end
  end
end
