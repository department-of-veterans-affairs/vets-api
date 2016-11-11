# frozen_string_literal: true
module V0
  class UsersController < ApplicationController
    def show
      render json: @current_user, session: @session
    end
  end
end
