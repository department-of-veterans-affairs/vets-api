# frozen_string_literal: true

module Mobile
  module V0
    class UsersController < ApplicationController
      after_action :handle_vet360_id, only: %i[show logged_in]

      def show
        map_logingov_to_idme
        render json: Mobile::V0::UserSerializer.new(@current_user, user_accessible_services.authorized, options)
      end

      # called by the mobile app after successful login. performs login-related actions
      def logged_in
        head(:ok)
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
            available_services: user_accessible_services.available
          }
        }
      end

      # solution so old app versions will still treat LOGINGOV accounts as multifactor
      def map_logingov_to_idme
        if @current_user.identity.sign_in[:service_name].include? 'LOGINGOV'
          @current_user.identity.sign_in[:service_name] = 'oauth_IDME'
        end
      end

      def user_accessible_services
        @user_accessible_services ||= Mobile::V0::UserAccessibleServices.new(current_user, request)
      end

      def handle_vet360_id
        return if @current_user.vet360_id.present?
        return log_missing_icn if @current_user.icn.blank?

        Mobile::V0::Vet360LinkingJob.perform_async(@current_user.uuid)
      end

      def log_missing_icn
        Rails.logger.warn('Mobile Vet360LinkingJob skipped - user has no ICN',
                          { user_uuid: @current_user.uuid })
      end
    end
  end
end
