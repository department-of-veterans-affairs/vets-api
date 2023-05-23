# frozen_string_literal: true

module Mobile
  module V0
    class UsersController < ApplicationController
      after_action :pre_cache_resources, only: :show

      def show
        map_logingov_to_idme
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

      def pre_cache_resources
        if Flipper.enabled?(:mobile_precache_appointments)
          Mobile::V0::PreCacheAppointmentsJob.perform_async(@current_user.uuid)
        end
        Mobile::V0::PreCacheClaimsAndAppealsJob.perform_async(@current_user.uuid)
      end

      # solution so old app versions will still treat LOGINGOV accounts as multifactor
      def map_logingov_to_idme
        if @current_user.identity.sign_in[:service_name].include? 'LOGINGOV'
          @current_user.identity.sign_in[:service_name] = 'oauth_IDME'
        end
      end
    end
  end
end
