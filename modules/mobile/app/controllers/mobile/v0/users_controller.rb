# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class UsersController < ApplicationController
      def show
        render json: Mobile::V0::UserSerializer.new(@current_user, options)
      end

      def logout
        session_manager = IAMSSOeOAuth::SessionManager.new(access_token)
        session_manager.logout

        head(:ok)
      end

      private

      def options
        {
          meta: {
            available_services: Mobile::V0::UserSerializer::SERVICE_DICTIONARY.keys
          }
        }
      end
    end
  end
end
