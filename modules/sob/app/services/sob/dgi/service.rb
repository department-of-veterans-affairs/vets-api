# frozen_string_literal: true

require 'sob/authentication_token_service'

module SOB
  module DGI
    class Service < ::Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration SOB::DGI::Configuration

      BENEFIT_TYPE = 'CH33'
      INCLUDE_ENROLLMENTS = 'NO'
      STATSD_KEY_PREFIX = 'api.sob.dgi'

      def initialize(ssn)
        super()
        raise Common::Exceptions::ParameterMissing, 'SSN' if ssn.blank?

        @ssn = ssn
      end

      def get_ch33_status
        with_monitoring do
          raw_response = perform(
            :post,
            end_point,
            payload.to_json,
            request_headers
          )
          raise_claimant_not_found if raw_response.status == 204

          SOB::DGI::Response.new(raw_response.status, raw_response)
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

      def raise_claimant_not_found
        status_code = 404
        msg = "#{config.service_name}_#{status_code}"
        raise Common::Exceptions::BackendServiceException.new(msg, {}, status_code)
      end

      def log_error(error)
        error_context = {
          service: 'SOB/DGI',
          error_class: error.class.name,
          error_status: error.original_status,
          timestamp: Time.current.iso8601
        }

        Rails.logger.error('SOB/DGI service error',
                           error_context,
                           backtrace: error.backtrace)
      end
    end
  end
end
