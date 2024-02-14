# frozen_string_literal: true

require 'va_profile/profile/v3/service'

module V0
  module Profile
    class MilitaryOccupationsController < ApplicationController
      service_tag 'military-info'
      before_action :controller_enabled?
      before_action { authorize :vet360, :military_access? }

      def show
        response = service.get_military_occupations
        render(status: response.status, json: response)
      end

      private

      def controller_enabled?
        routing_error unless Flipper.enabled?(:profile_enhanced_military_info, @current_user)
      end

      def service
        @service ||= VAProfile::Profile::V3::Service.new(@current_user)
      end
    end
  end
end
