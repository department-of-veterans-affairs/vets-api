# frozen_string_literal: true

require 'va_profile/profile/v3/service'

module V1
  module Profile
    # NOTE: This controller is used for discovery purposes.
    # Please contact the Authenticated Experience Profile team before using.
    class MilitaryInfosController < ApplicationController
      service_tag 'military-info'
      before_action :controller_enabled?
      before_action { authorize :vet360, :military_access? }

      def show
        response = service.get_military_info
        render status: response.status, json: response.body
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
