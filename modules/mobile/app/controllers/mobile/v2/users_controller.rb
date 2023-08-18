# frozen_string_literal: true

module Mobile
  module V2
    class UsersController < ApplicationController
      after_action :handle_vet360_id, only: :show

      def show
        render json: Mobile::V2::UserSerializer.new(@current_user)
      end

      private

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
