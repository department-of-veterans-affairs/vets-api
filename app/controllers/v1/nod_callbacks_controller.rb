# frozen_string_literal: true

module V1
  class NodCallbacksController < ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    service_tag 'nod-callbacks'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]
    skip_after_action :set_csrf_header, only: [:create]
    before_action :authenticate_header, only: [:create]

    def create
      unless Flipper.enabled? :nod_callbacks_endpoint
        return render json: nil, status: :not_found
      end

      Rails.logger.info(JSON.parse(request.body.string))

      # TODO: save encrypted request body in database table for non-successful notifications

      render json: { message: 'success' }
    end

    private

    def authenticate_header
      authenticate_user_with_token || authenticity_error
    end

    def authenticate_user_with_token
      Rails.logger.debug("Received request, authenticating!")
      authenticate_with_http_token do |token, options|
        return false if bearer_token_secret.nil?
        token == bearer_token_secret
      end
    end

    def authenticity_error
      Rails.logger.debug("Failed to authenticate request")
      render json: { message: "Invalid credentials" }, status: :unauthorized
    end

    def bearer_token_secret
      Settings.dig(:nod_callbacks, :bearer_token)
    end
  end
end
