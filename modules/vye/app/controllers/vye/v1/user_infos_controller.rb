# frozen_string_literal: true

module Vye
  module V1
    class UserInfosController < Vye::V1::ApplicationController
      include Vye::Ivr

      def show
        authorize user_info, policy_class: Vye::UserInfoPolicy

        render json: user_info,
               serializer: Vye::UserInfoSerializer,
               adapter: :json,
               api_key: api_key?,
               include: %i[latest_address pending_documents verifications pending_verifications].freeze
      end

      private

      def load_user_info(scoped: Vye::UserProfile.with_assos)
        return super(scoped:) unless api_key?

        @user_info = user_info_for_ivr(scoped:)
      end
    end
  end
end
