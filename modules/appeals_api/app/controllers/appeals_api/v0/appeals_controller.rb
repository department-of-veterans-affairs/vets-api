# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
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

      private

      def log_request
        hashed_ssn = Digest::SHA2.hexdigest ssn
        Rails.logger.info('Caseflow Request',
                          'consumer' => consumer,
                          'va_user' => requesting_va_user,
                          'lookup_identifier' => hashed_ssn)
      end

      def log_response(appeals_response)
        first_appeal_id = appeals_response.body['data'][0]['id']
        count = appeals_response.body['data'].length
        Rails.logger.info('Caseflow Response',
                          'consumer' => consumer,
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

      def target_veteran
        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end
    end
  end
end
