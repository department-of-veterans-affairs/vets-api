# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsApi
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        appeals_response = Appeals::Service.new.get_appeals(
          target_veteran,
          'Consumer' => consumer,
          'VA-User' => requesting_va_user
        )
        log_response(
          first_appeal_id: appeals_response.body['data'][0]['id'],
          count: appeals_response.body['data'].length
        )
        render(
          json: appeals_response.body
        )
      end

      private

      def target_veteran
        veteran = OpenStruct.new
        veteran.ssn = ssn
        veteran
      end
    end
  end
end
