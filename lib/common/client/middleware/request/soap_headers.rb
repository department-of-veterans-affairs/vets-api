# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Request
        class SOAPHeaders < Faraday::Middleware
          def call(env)
            env.request_headers['Date'] = Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
            env.request_headers['Content-Length'] = env.body.bytesize.to_s
            @app.call(env)
          end
        end
      end
    end
  end
end

Faraday::Request.register_middleware soap_headers: Common::Client::Middleware::Request::SOAPHeaders
