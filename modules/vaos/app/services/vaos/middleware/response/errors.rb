# frozen_string_literal: true

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        def on_complete(env)
          return if env.success?

          caller = "VAOS.#{caller_locations(14, 1)[0].label}"
          Raven.extra_context(message: env.body, url: env.url)
          case env.status
          when 403
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_403',
              source: caller
            )
          when 500
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_502',
              source: caller
            )
          else
            raise Common::Exceptions::BackendServiceException.new(
              'VA900',
              source: caller
            )
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
