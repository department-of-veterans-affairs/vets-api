# frozen_string_literal: true

require 'mhv/oh_facilities_helper/service'

module Mobile
  module V0
    class AuthorizedServicesController < ApplicationController
      def index
        options = { meta: get_metadata }
        render json: Mobile::V0::AuthorizedServicesSerializer.new(@current_user.uuid,
                                                                  user_accessible_services.service_auth_map, options)
      end

      private

      def user_accessible_services
        @user_accessible_services ||= Mobile::V0::UserAccessibleServices.new(current_user, request)
      end

      def get_metadata
        service = MHV::OhFacilitiesHelper::Service.new(@current_user)
        {
          is_user_at_pretransitioned_oh_facility: service.user_at_pretransitioned_oh_facility?,
          is_user_facility_ready_for_info_alert: service.user_facility_ready_for_info_alert?,
          migrating_facilities_list: if Flipper.enabled?(:mhv_oh_migration_schedules, @current_user)
                                       service.get_migration_schedules
                                     else
                                       []
                                     end
        }
      end
    end
  end
end
