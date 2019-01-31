# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
        if header('X-Consumer-PoA').present?
          verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
          verifier.verify(header('X-Consumer-PoA'))
        end
        appeals_response = Appeals::Service.new.get_appeals(
          target_veteran,
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
        log_response(appeals_response)
        render(
          json: appeals_response.body
        )
      end

      def healthcheck
        render json: Appeals::Service.new.healthcheck.body
      end

      private

      def log_request
        hashed_ssn = Digest::SHA2.hexdigest ssn
        Rails.logger.info('Caseflow Request',
                          'va_user' => requesting_va_user,
                          'lookup_identifier' => hashed_ssn)
      end

      def log_response(appeals_response)
        first_appeal_id = appeals_response.body.dig('data', 0, 'id')
        count = appeals_response.body['data'].length
        Rails.logger.info('Caseflow Response',
                          'va_user' => requesting_va_user,
                          'first_appeal_id' => first_appeal_id,
                          'appeal_count' => count)
      end

      def consumer
        request.headers['X-Consumer-Username']
      end

      def ssn
        ssn = request.headers['X-VA-SSN']
        raise Common::Exceptions::ParameterMissing, 'X-VA-SSN' unless ssn
        ssn
      end

      def requesting_va_user
        va_user = request.headers['X-VA-User']
        raise Common::Exceptions::ParameterMissing, 'X-VA-User' unless va_user
        va_user
      end

      def first_name
        va_first_name = header('X-VA-First-Name')
        raise Common::Exceptions::ParameterMissing, 'X-VA-First-Name' unless va_first_name
        va_first_name
      end

      def last_name
        va_last_name = header('X-VA-Last-Name')
        raise Common::Exceptions::ParameterMissing, 'X-VA-Last-Name' unless va_last_name
        va_last_name
      end

      def edipi
        va_edipi = header('X-VA-EDIPI')
        raise Common::Exceptions::ParameterMissing, 'X-VA-EDIPI' unless va_edipi
        va_edipi
      end

      def header(key)
        request.headers[key]
      end

      def target_veteran
        if header('X-Consumer-PoA').present?
          ClaimsApi::Veteran.new(
            ssn: ssn,
            loa: { current: :loa3 },
            first_name: first_name,
            last_name: last_name,
            edipi: edipi,
            last_signed_in: Time.zone.now
          )
        else
          OpenStruct.new(ssn: ssn)
        end
      end
    end
  end
end
