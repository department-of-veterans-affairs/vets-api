# frozen_string_literal: true

module Mobile
  module V1
    class UsersController < ApplicationController
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
