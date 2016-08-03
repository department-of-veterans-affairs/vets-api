# example controller to show use of logging in with sessions controller

module V0
  class ExampleController < ApplicationController
    before_action :require_login, only: [:welcome]

    def index
      render json: { "message": "Welcome to the vets.gov API" }
    end

    def welcome
      current_user = session[:user]["attributes"]["email"].first
      msg = "You are logged in as #{current_user}"
      render json: { "message": msg }
    end
  end
end
