# frozen_string_literal: true

module Mobile
  module V1
    class UsersController < ApplicationController
      after_action :pre_cache_resources, only: :show
      after_action :handle_vet360_id, only: :show

      def show
        render json: Mobile::V1::UserSerializer.new(@current_user, user_accessible_services.authorized, options)
      end

      private

      def options
        {
          meta: {
            available_services: user_accessible_services.available
          }
        }
      end

      def pre_cache_resources
        if Flipper.enabled?(:mobile_precache_appointments)
          Mobile::V0::PreCacheAppointmentsJob.perform_async(@current_user.uuid)
        end
        Mobile::V0::PreCacheClaimsAndAppealsJob.perform_async(@current_user.uuid)
      end

      def user_accessible_services
        @user_accessible_services ||= Mobile::V0::UserAccessibleServices.new(current_user)
      end

      def handle_vet360_id
        if @current_user.vet360_id.blank?
          Mobile::V0::Vet360LinkingJob.perform_async(@current_user.uuid)
        elsif (mobile_user = Mobile::User.find_by(icn: @current_user.icn, vet360_linked: false))
          Rails.logger.info('Mobile Vet360 account linking was successful request succeeded for user with uuid',
                            { user_icn: @current_user.icn, attempts: mobile_user.vet360_link_attempts })
          mobile_user.update(vet360_linked: true)
        end
      end
    end
  end
end
