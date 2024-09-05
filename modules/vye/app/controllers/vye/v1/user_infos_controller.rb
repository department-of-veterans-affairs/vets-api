# frozen_string_literal: true

module Vye
  module V1
    class UserInfosController < Vye::V1::ApplicationController
      def show
        authorize user_info, policy_class: Vye::UserInfoPolicy

        render json: Vye::UserInfoSerializer.new(user_info)
      end
    end
  end
end
