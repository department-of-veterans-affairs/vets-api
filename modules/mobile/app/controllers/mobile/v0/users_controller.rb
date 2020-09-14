# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class UsersController < ApplicationController
      def show
        render json: Mobile::V0::UserSerializer.new(@current_user)
      end
    end
  end
end
