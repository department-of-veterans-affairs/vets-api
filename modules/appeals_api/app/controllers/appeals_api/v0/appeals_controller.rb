# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)
      skip_before_action :log_request, only: [:healthcheck]

      def index
        appeals_response = Appeals::Service.new.get_appeals(
          target_veteran,
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
        log_response(appeals_log_attributes(appeals_response))
        render(
          json: appeals_response.body
        )
      end

      def healthcheck
        render json: Appeals::Service.new.healthcheck.body
      end

      private

      def appeals_log_attributes(appeals_response)
        {
          'first_appeal_id' => appeals_response.body['data'][0]['id'],
          'appeal_count' => appeals_response.body['data'].length
        }
      end

      def target_veteran
        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end
    end
  end
end
