# frozen_string_literal: true

module Vye
  module V1
    class UserInfosController < Vye::V1::ApplicationController
      def show
        # Check if user_info is nil after being loaded by the before_action
        # If nil, it means the resource for the current user was not found
        if user_info.nil?
          raise Vye::ResourceNotFound, { detail: 'No active VYE user information found for the current user.' }
        end

        authorize user_info, policy_class: Vye::UserInfoPolicy

        render json: Vye::UserInfoSerializer.new(user_info)
      end
    end
  end
end
