# frozen_string_literal: true

module Mobile
  module V0
    class AuthorizedServicesController < ApplicationController
      def index
        render json: Mobile::V0::AuthorizedServicesSerializer.new(@current_user.id,
                                                                  user_accessible_services.service_auth_map)
      end

      private

      def user_accessible_services
        @user_accessible_services ||= Mobile::V0::UserAccessibleServices.new(current_user)
      end
    end
  end
end
