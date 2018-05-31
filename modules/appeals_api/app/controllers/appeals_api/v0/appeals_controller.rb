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
          'X-Consumer-Username' => request.headers['X-Consumer-Username']
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
                          'lookup_identifier' => hashed_ssn)
      end

      def log_response(appeals_response)
        first_appeal_id = appeals_response.body['data'][0]['id']
        count = appeals_response.body['data'].length
        Rails.logger.info('Caseflow Response',
                          'consumer' => consumer,
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

      def user
        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end
    end
  end
end
