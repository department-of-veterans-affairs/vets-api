# frozen_string_literal: true

require 'sob/authentication_token_service'

module SOB
  module DGIB
    class Service < ::Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration SOB::DGIB::Configuration

      BENEFIT_TYPE = 'CH33'
      INCLUDE_ENROLLMENTS = 'NO'
      STATSD_KEY_PREFIX = 'api.sob.dgib'

      def initialize(ssn)
        super()
        raise Common::Exceptions::ParameterMissing, 'SSN' if ssn.blank?

        @ssn = ssn
      end

      def get_ch33_status
        with_monitoring do
          byebug
          raw_response = perform(
            :post,
            end_point,
            payload.to_json,
            request_headers
          )
          byebug
          raise
        end
      end

      private

      def payload
        {
          ssn: @ssn,
          benefitType: BENEFIT_TYPE,
          enrollment: INCLUDE_ENROLLMENTS
        }
      end

      def end_point
        'claimants'
      end

      def request_headers
        {
          Authorization: "Bearer #{SOB::AuthenticationTokenService.call}"
        }
      end
    end
  end
end
