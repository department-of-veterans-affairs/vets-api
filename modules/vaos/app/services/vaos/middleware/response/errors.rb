# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def on_complete(env)
          return if env.success?

          Raven.extra_context(vamf_status: env.status, vamf_body: env.body, vamf_url: env.url)
          case env.status
          when 400
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_400',
              response_values(env.url, env.body, env.status),
              env.status, env.body
            )
          when 403
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_403',
              response_values(env.url, env.body, env.status),
              env.status, env.body
            )
          when 404
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_404',
              response_values(env.url, env.body, env.status),
              env.status, env.body
            )
          when 409
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_409A',
              response_values(env.url, env.body, env.status),
              env.status, env.body
            )
          when 500..510
            error_500(env.url, env.body, env.status)
          else
            raise Common::Exceptions::BackendServiceException.new(
              'VA900',
              response_values(env.url, env.body, env.status),
              env.status, env.body
            )
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        private

        def error_500(url, body, status)
          # NOTE: This is a temporary patch more on that here:
          # https://github.com/department-of-veterans-affairs/vets-api/pull/5082
          if /APTCRGT/.match?(body)
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_400',
              response_values(url, body, status),
              status, body
            )
          else
            raise Common::Exceptions::BackendServiceException.new(
              'VAOS_502',
              response_values(url, body, status),
              status, body
            )
          end
        end

        def response_values(url, body, status)
          {
            detail: detail(body),
            source: { vamf_url: url, vamf_body: body, vamf_status: status }
          }
        end

        def detail(body)
          parsed = JSON.parse(body)
          if parsed['errors']
            parsed['errors'].first['errorMessage']
          else
            parsed['message']
          end
        rescue
          body
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
