# frozen_string_literal: true

module Vye
  module V1
    class UserInfosController < Vye::V1::ApplicationController
      def show
        authorize user_info, policy_class: Vye::UserInfoPolicy

        render json: user_info,
               serializer: Vye::UserInfoSerializer,
               adapter: :json,
               include: %i[latest_address pending_documents verifications pending_verifications].freeze
      end
    end
  end
end
