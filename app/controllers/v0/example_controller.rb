# example controller to show use of logging in with sesssions controller

module V0
  class ExampleController < ApplicationController

    def index
      render json: { "message": "Welcome to the vets.gov API"}
    end

    # requires log in
    def welcome
      if session[:user]
        current_user = session[:user]["attributes"]["email"].first
        msg = "You are logged in as #{current_user}"
        render json: { "message": msg }
      else
        redirect_to new_v0_sessions_path
      end
    end
  end
end