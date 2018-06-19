# frozen_string_literal: true

module V0
  class UsersController < ApplicationController
    def show
      render json: @current_user
    end

    def authorized_for_service?
      render json: ServiceAuthDetail.new(@current_user, params),
             serializer: ServiceAuthDetailSerializer
    end
  end
end
