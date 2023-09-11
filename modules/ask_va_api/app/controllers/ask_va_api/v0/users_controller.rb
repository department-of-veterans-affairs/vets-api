# frozen_string_literal: true

module AskVAApi
  module V0
    class UsersController < ApplicationController
      def show
        user_inquiries = Users::UserInquiriesCreator.new(uuid: current_user.uuid).call

        render json: Users::UserInquiriesSerializer.new(user_inquiries).serializable_hash, status: :ok
      end
    end
  end
end
