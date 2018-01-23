# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class MHVErrors < Faraday::Response::Middleware
          def on_complete(env)
            return if env.success?
            env[:body]['code'] = env[:body].delete('errorCode')
            env[:body]['detail'] = env[:body].delete('message')
            env[:body]['source'] = env[:body].delete('developerMessage')
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware mhv_errors: Common::Client::Middleware::Response::MHVErrors
