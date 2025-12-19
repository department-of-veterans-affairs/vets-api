# frozen_string_literal: true

require 'sob/authentication_token_service'

module SOB
  module DGI
    class Service < ::Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration SOB::DGI::Configuration

      BENEFIT_TYPE = 'CH33'
      ENROLLMENT_PARAM = 'NO'
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
          # Expect 204 from DGI if claimant not found
          raise_claimant_not_found if response_204?(raw_response)

          begin
            SOB::DGI::Response.new(raw_response.status, raw_response)
          rescue SOB::DGI::Response::Ch33DataMissing
            raise_claimant_not_found
          end
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
          enrollment: ENROLLMENT_PARAM
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

      # Encountered staging response where status was 200 but body was '{"status":204,"claimant":null}'
      def response_204?(res)
        [res.body&.dig('status'), res.status].any? { |status| status == 204 }
      end

      # Convert DGI 204 response into 404 error
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
