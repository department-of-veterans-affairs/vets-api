# frozen_string_literal: true

module AskVAApi
  module V0
    class UsersController < ApplicationController
      def show
        user_inquiries = DynamicsService.new.get_submitter_inquiries(uuid: current_user.uuid)
        if user_inquiries.is_a?(String)
          render json: user_inquiries, status: :unauthorized
        else
          render json: UserInquiriesSerializer.new(user_inquiries).serializable_hash, status: :ok
        end
      end
    end
  end
end
