# frozen_string_literal: true

require_dependency 'appeals_api/application_controller'

module AppealsAPI
  module V0
    class AppealsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :ssn_header_present

      VA_SSN_HEADER = 'X-VA-SSN'

      def user
        veteran = OpenStruct.new
        veteran.ssn = request.headers[VA_SSN_HEADER]
        veteran
      end

      def index
        appeals_response = Appeals::Service.new.get_appeals(user)
        render(
          json: appeals_response.body
        )
      end

      private

      def ssn_header_present
        unless request.headers.has_key?(VA_SSN_HEADER)
          raise Common::Exceptions::ParameterMissing, VA_SSN_HEADER
        end
      end
    end
  end
end
