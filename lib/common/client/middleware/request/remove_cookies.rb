module Common
  module Client
    module Middleware
      module Request
        class RemoveCookies < Faraday::Middleware
          def call(env)
            p @app.client.cookie_manager.cookies
            # @app.client.cookie_manager.cookies = []
            @app.call(env)
          end
        end
      end
    end
  end
end
