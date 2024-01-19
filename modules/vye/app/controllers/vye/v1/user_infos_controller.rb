# frozen_string_literal: true

module Vye
  module V1
    class UserInfosController < Vye::V1::ApplicationController
      include Pundit::Authorization
      service_tag 'vye'

      def show
        authorize user_info, policy_class: Vye::UserInfoPolicy

        render json: user_info,
               serializer: Vye::UserInfoSerializer,
               key_transform: :camel_lower,
               adapter: :json,
               include: %i[awards pending_documents verifications]
      end

      private

      def load_user_info
        @user_info = Vye::UserInfo
                     .includes(:awards, :pending_documents, :verifications)
                     .find_and_update_icn(user: current_user)
      end
    end
  end
end
