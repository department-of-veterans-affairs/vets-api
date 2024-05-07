# frozen_string_literal: true

module Vye
  module V1
    class UserInfosController < Vye::V1::ApplicationController
      include Pundit::Authorization

      service_tag 'verify-your-enrollment'

      def show
        authorize user_info, policy_class: Vye::UserInfoPolicy

        render json: user_info,
               serializer: Vye::UserInfoSerializer,
               key_transform: :camel_lower,
               adapter: :json,
               include: %i[awards address_changes pending_documents].freeze
      end

      private

      def load_user_info
        @user_info = Vye::UserProfile.with_assos.find_and_update_icn(user: current_user)&.active_user_info
      end
    end
  end
end
