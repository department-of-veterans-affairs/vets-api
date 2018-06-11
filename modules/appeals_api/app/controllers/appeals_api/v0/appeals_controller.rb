# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        log_request
        appeals_response = Appeals::Service.new.get_appeals(
          user,
          'Consumer-Username' => consumer
          'VA-User' => requesting_user
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
                          'requested_by' => requesting_user,
                          'lookup_identifier' => hashed_ssn)
      end

      def log_response(appeals_response)
        first_appeal_id = appeals_response.body['data'][0]['id']
        count = appeals_response.body['data'].length
        Rails.logger.info('Caseflow Response',
                          'consumer' => consumer,
                          'requested_by' => requesting_user,
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

      def requesting_user
        user = request.headers['X-VA-User']
        raise Common::Exceptions::ParameterMissing, 'X-VA-User' unless user
        user
      end

      def user
        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end
    end
  end
end
