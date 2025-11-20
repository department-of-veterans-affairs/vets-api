# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Exceptions
    class BackendServiceException < Common::Exceptions::BackendServiceException
      # rubocop:disable Style/MutableConstant
      VAOS_ERRORS = {
        400 => 'VAOS_400',
        403 => 'VAOS_403',
        404 => 'VAOS_404',
        409 => 'VAOS_409A',
        500 => 'VAOS_502',
        501 => 'VAOS_502',
        502 => 'VAOS_502',
        503 => 'VAOS_502',
        504 => 'VAOS_502',
        505 => 'VAOS_502',
        506 => 'VAOS_502',
        507 => 'VAOS_502',
        508 => 'VAOS_502',
        509 => 'VAOS_502',
        510 => 'VAOS_502'
      }

      VAOS_ERRORS.default = 'VA900'

      def initialize(env)
        @env = env
        key = VAOS_ERRORS[env.status]
        super(key, response_values, env.status, env.body)
      end

      def response_values
        {
          detail: extract_detail(@env.body),
          source: { vamf_url: VAOS::Anonymizers.anonymize_uri_icn(@env.url), vamf_body: @env.body,
                    vamf_status: @env.status }
        }
      end

      # Override parent's detail method to match signature
      def detail
        response_values[:detail]
      end

      private

      def extract_detail(body)
        parsed = JSON.parse(body)
        if parsed['errors']
          parsed['errors'].first['errorMessage']
        else
          parsed['message']
        end
      rescue
        body
      end
      # rubocop:enable Style/MutableConstant
    end
  end
end
