# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      VA_SSN_HEADER = 'X-VA-SSN'

      def index
        appeals_response = Appeals::Service.new.get_appeals(user)
        log_response(appeals_response)
        render(
          json: appeals_response.body
        )
      end

      private

      def log_response(appeals_response)
        consumer = request.headers['X-Consumer-Username']
        first_appeals_id = appeals_response.body['data'][0]['id']
        Rails.logger.info("Caseflow request by #{consumer} retrieved #{first_appeals_id}")
      end

      def user
        ssn = request.headers[VA_SSN_HEADER]
        raise Common::Exceptions::ParameterMissing, VA_SSN_HEADER unless ssn

        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end
    end
  end
end
