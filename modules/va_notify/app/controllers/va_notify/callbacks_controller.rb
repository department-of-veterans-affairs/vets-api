# frozen_string_literal: true

module VANotify
  class CallbacksController < VANotify::ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    skip_before_action :verify_authenticity_token, :authenticate, only: [:create]

    before_action :authenticate_callback

    def create
      Rails.logger.debug "Notification received: #{params.inspect}"
      render json: { message: 'success' }, status: :ok
    end

    def authenticate_callback
      authenticate_token || authenticity_error
    end

    def authenticate_token
      authenticate_with_http_token do |token|
        return false if bearer_token_secret.nil?

        ActiveSupport::SecurityUtils.secure_compare(token, bearer_token_secret)
      end
    end

    def authenticity_error
      Rails.logger.info('va_notify callbacks - Failed to authenticate request')
      render json: { message: 'Unauthorized' }, status: :unauthorized
    end

    def bearer_token_secret
      Settings.dig(:va_notify, :status_callback, :bearer_token)
    end
  end
end
