# frozen_string_literal: true

module Mobile
  module V1
    class UsersController < ApplicationController
      after_action :pre_cache_resources, only: :show
      after_action :link_user_with_vet360, only: :show, if: -> { @current_user.vet360_id.blank? }

      def show
        render json: Mobile::V1::UserSerializer.new(@current_user, options)
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

      def link_user_with_vet360
        Mobile::V0::Vet360LinkingJob.perform_async(@current_user.uuid)
      end
    end
  end
end
