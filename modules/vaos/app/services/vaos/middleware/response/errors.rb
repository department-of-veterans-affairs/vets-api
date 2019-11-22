# frozen_string_literal: true

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        def on_complete(env)
          return if env.success?

          Raven.extra_context(message: env.body, url: env.url)
          binding.pry
          case env.status
          when 400
            error_400(env.body)
          when 403
            raise Common::Exceptions::BackendServiceException.new('VAOS_403', source: self.class)
          when 500..510
            raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class)
          else
            raise Common::Exceptions::BackendServiceException.new('VA900', source: self.class)
          end
        end

        def error_400(body)
          raise Common::Exceptions::BackendServiceException.new(
            'VAOS_400',
            title: 'Bad Request',
            detail: body,
            source: self.class
          )
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
