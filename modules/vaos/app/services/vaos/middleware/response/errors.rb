# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Middleware
    module Response
      class Errors < Faraday::Response::Middleware
        def on_complete(env)
          return if env.success?

          @status = env.status
          @body = env.body
          @url = env.url

          Raven.extra_context(vamf_status: @status, vamf_body: @body, vamf_url: @url)
          case env.status
          when 400, 409
            raise Common::Exceptions::BackendServiceException.new('VAOS_400', response_values, @status, @body)
          when 403
            raise Common::Exceptions::BackendServiceException.new('VAOS_403', response_values, @status, @body)
          when 404
            raise Common::Exceptions::BackendServiceException.new('VAOS_404', response_values, @status, @body)
          when 500..510
            error_500
          else
            raise Common::Exceptions::BackendServiceException.new('VA900', response_values, @status, @body)
          end
        end

        private

        def error_500
          # NOTE: This is a temporary patch more on that here:
          # https://github.com/department-of-veterans-affairs/vets-api/pull/5082
          if /APTCRGT/.match?(@body)
            raise Common::Exceptions::BackendServiceException.new('VAOS_400', response_values, @status, @body)
          else
            raise Common::Exceptions::BackendServiceException.new('VAOS_502', response_values, @status, @body)
          end
        end

        def response_values
          {
            detail: detail,
            source: { vamf_url: @url, vamf_body: @body, vamf_status: @status }
          }
        end

        def detail
          parsed = JSON.parse(@body)
          if parsed['errors']
            parsed['errors'].first['errorMessage']
          else
            parsed['message']
          end
        rescue
          @body
        end
      end
    end
  end
end

Faraday::Response.register_middleware vaos_errors: VAOS::Middleware::Response::Errors
