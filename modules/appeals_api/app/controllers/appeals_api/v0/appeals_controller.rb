# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
        verify_poa
        log_response(appeals_response)
        render(
          json: appeals_response.body
        )
      end

      def healthcheck
        render json: Appeals::Service.new.healthcheck.body
      end

      private

      def service
        @service ||= Appeals::Service.new(target_veteran)
      end

      def appeals_response
        service.get_appeals(
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
      end

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
        request.headers['X-VA-User'] || request.headers['X-Consumer-Username']
      end

      def verify_poa
        if request.headers['X-Consumer-Custom-ID']
          unless request.headers['X-Consumer-Custom-ID'].split(',').include?(veteran_power_of_attorney)
            raise Common::Exceptions::Unauthorized, detail: "Power of Attorney code doesn't match Veteran's"
          end
        end
      end

      def target_veteran
        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end

      def veteran_power_of_attorney
        service.power_of_attorney['currentPoa'].try(:[], 'code')
      end
    end
  end
end
