# frozen_string_literal: true

# example controller to show use of logging in with sessions controller

module V0
  class ExampleController < ApplicationController
    before_action :authenticate, only: [:welcome]

    def index
      render json: { message: 'Welcome to the va.gov API' }
    end

    def limited
      render json: { message: 'Rate limited action' }
    end

    def welcome
      msg = "You are logged in as #{@current_user.email}"
      render json: { message: msg }
    end

    def healthcheck
      render status: :ok
    end

    def startup_healthcheck
      render status: :ok
    end
  end
end
