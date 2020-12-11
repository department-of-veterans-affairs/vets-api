# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module Exceptions
    class BackendServiceException < Common::Exceptions::BackendServiceException
      # rubocop:disable Style/MutableConstant, Style/CaseEquality
      VAOS_ERRORS = {
        400 => 'VAOS_400',
        403 => 'VAOS_403',
        404 => 'VAOS_404',
        409 => 'VAOS_409A',
        500..510 => 'VAOS_502'
      }

      VAOS_ERRORS.default = 'VA900'

      def initialize(env)
        binding.pry
        @env = env
        key = lookup_key(env.status)
        super(key, response_values, env.status, env.body)
      end

      def response_values
        {
          detail: detail(@env.body),
          source: { vamf_url: @env.url, vamf_body: @env.body, vamf_status: @env.status }
        }
      end

      private

      def lookup_key(status)
        VAOS_ERRORS.select { |status_code| status_code === status }.values.first
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
      # rubocop:enable Style/MutableConstant, Style/CaseEquality
    end
  end
end
