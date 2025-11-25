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

      class ClaimantNotFoundError < Common::Exceptions::BackendServiceException
        STATUS_CODE = 400

        def initialize(service_name)
          key = "#{service_name}_#{STATUS_CODE}"
          super(key, {}, STATUS_CODE)
        end
      end

      def initialize(ssn)
        super()
        raise Common::Exceptions::ParameterMissing, 'SSN' if ssn.blank?

        @ssn = '500'
      end

      def get_ch33_status
        with_monitoring do
          raw_response = perform(
            :post,
            end_point,
            payload.to_json,
            request_headers
          )
          raise ClaimantNotFoundError, config.service_name if raw_response.status == 204

          SOB::DGIB::Response.new(raw_response.status, raw_response)
        end
      rescue Common::Exceptions::BackendServiceException => e
        log_error(e)
        raise e
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

      def log_error(error)
        error_context = {
          service: 'SOB/DGIB',
          error_class: error.class.name,
          error_status: error.original_status,
          timestamp: Time.current.iso8601
        }

        Rails.logger.error('SOB/DGIB service error',
                           error_context,
                           backtrace: error.backtrace)
      end
    end
  end
end
