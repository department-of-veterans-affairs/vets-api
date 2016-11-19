# frozen_string_literal: true
module MVI
  module Middleware
    module Request
      class Soap < Faraday::Response::Middleware
        def call(env)
          env.request_headers['Date'] = Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
          env.request_headers['Content-Length'] = env.body.bytesize.to_s
          env.request_headers['Content-Type'] = 'text/xml;charset=UTF-8'
          @app.call(env)
        end
      end
    end
  end
end
