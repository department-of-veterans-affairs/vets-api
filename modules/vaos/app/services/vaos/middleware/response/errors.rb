# frozen_string_literal: true

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Middleware
        def on_complete(env)
          return if env.success?

          raise VAOS::Exceptions::BackendServiceException, env
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
