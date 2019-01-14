# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
        verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
        verifier.verify(header('X-Consumer-Custom-ID'))
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
        first_appeal_id = appeals_response.body['data'][0]['id']
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
        header(key = 'X-VA-First-Name') ? header(key) : raise_missing_header(key)
      end

      def last_name
        header(key = 'X-VA-Last-Name') ? header(key) : raise_missing_header(key)
      end

      def edipi
        header(key = 'X-VA-EDIPI') ? header(key) : raise_missing_header(key)
      end

      def birth_date
        header(key = 'X-VA-Birth-Date') ? header(key) : raise_missing_header(key)
      end

      def header(key)
        request.headers[key]
      end

      def va_profile
        OpenStruct.new(
          birth_date: header('X-VA-Birth-Date')
        )
      end

      def target_veteran
        ClaimsApi::Veteran.new(
          ssn: ssn,
          loa: { current: :loa3 },
          first_name: header('X-VA-First-Name'),
          last_name: header('X-VA-Last-Name'),
          va_profile: va_profile,
          edipi: header('X-VA-EDIPI'),
          last_signed_in: Time.zone.now
        )
      end

      def raise_missing_header(key)
        raise Common::Exceptions::ParameterMissing, key
      end
    end
  end
end
