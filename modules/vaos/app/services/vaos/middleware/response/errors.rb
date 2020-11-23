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
            error_400(env.body)
          when 403
            raise Common::Exceptions::BackendServiceException.new('VAOS_403', source: self.class)
          when 404
            raise Common::Exceptions::BackendServiceException.new('VAOS_404', source: self.class)
          when 500..510
            error_500(env.body)
          else
            raise Common::Exceptions::BackendServiceException.new('VA900', source: self.class)
          end
        end

        def error_500(body)
          # NOTE: This is a temporary patch more on that here:
          # https://github.com/department-of-veterans-affairs/vets-api/pull/5082
          if /APTCRGT/.match?(body)
            error_400(body)
          else
            raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class)
          end
        end

        def error_400(body)
          raise Common::Exceptions::BackendServiceException.new(
            'VAOS_400',
            title: 'Bad Request',
            detail: parse_error(body),
            source: self.class
          )
        end

        def parse_error(body)
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
