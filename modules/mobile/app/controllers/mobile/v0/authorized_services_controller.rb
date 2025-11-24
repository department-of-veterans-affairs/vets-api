# frozen_string_literal: true

module Mobile
  module V0
    class AuthorizedServicesController < ApplicationController
      def index
        render json: Mobile::V0::AuthorizedServicesSerializer.new(@current_user.uuid,
                                                                  user_accessible_services.service_auth_map,
                                                                  get_metadata)
      end

      private

      def user_accessible_services
        @user_accessible_services ||= Mobile::V0::UserAccessibleServices.new(current_user, request)
      end

      def get_metadata
        service = MHV::OhFacilitiesHelper::Service.new
        {
          meta: {
            is_user_at_pretransitioned_oh_facility: service.user_at_pretransitioned_oh_facility?,
            is_user_facility_ready_for_info_alert: service.user_facility_ready_for_info_alert?
          }
        }
      end
    end
  end
end
