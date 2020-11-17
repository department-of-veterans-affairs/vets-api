# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        def on_complete(env)
          return if env.success?

          Raven.extra_context(vamf_status: env.status, vamf_body: env.body, vamf_url: env.url)
          case env.status
          when 400, 409
            raise Common::Exceptions::BackendServiceException.new('VAOS_400', response_values, env.status, env.body)
          when 403
            raise Common::Exceptions::BackendServiceException.new('VAOS_403', response_values, env.status, env.body)
          when 404
            raise Common::Exceptions::BackendServiceException.new('VAOS_404', response_values, env.status, env.body)
          when 500..510
            error_500
          else
            raise Common::Exceptions::BackendServiceException.new('VA900', response_values, env.status, env.body)
          end
        end

        private

        def error_500
          # NOTE: This is a temporary patch more on that here:
          # https://github.com/department-of-veterans-affairs/vets-api/pull/5082
          if /APTCRGT/.match?(env.body)
            raise Common::Exceptions::BackendServiceException.new('VAOS_400', response_values, env.status, env.body)
          else
            raise Common::Exceptions::BackendServiceException.new('VAOS_502', response_values, env.status, env.body)
          end
        end

        def response_values
          {
            detail: detail,
            source: { vamf_url: env.url, vamf_body: env.body, vamf_status: env.status }
          }
        end

        def detail
          parsed = JSON.parse(env.body)
          if parsed['errors']
            parsed['errors'].first['errorMessage']
          else
            parsed['message']
          end
        rescue
          env.body
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
