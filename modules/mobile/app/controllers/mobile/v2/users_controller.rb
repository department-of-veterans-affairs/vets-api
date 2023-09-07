# frozen_string_literal: true

module Mobile
  module V2
    class UsersController < ApplicationController
      def show
        render json: Mobile::V2::UserSerializer.new(@current_user)
      end
    end
  end
end
