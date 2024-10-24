# frozen_string_literal: true

module SimpleFormsApi
  module V1
    class CallbacksController < ApplicationController
      include ActionController::HttpAuthentication::Token::ControllerMethods

      skip_before_action :verify_authenticity_token, only: [:create]
      skip_before_action :authenticate, only: [:create]
      skip_after_action :set_csrf_header, only: [:create]
      before_action :authenticate_header, only: [:create]

      def create
        return render json: nil, status: :not_found unless Flipper.enabled? :simple_forms_callbacks_endpoint

        status = params[:status]
        status_reason = params[:status_reason]
        notification_type = params[:notification_type]

        Rails.logger.info(
          'Simple forms api - VANotify callback received',
          { status:, status_reason:, notification_type: }
        )

        head :ok
      end

      private

      def authenticate_header
        authenticate_user_with_token || authenticity_error
      end

      def authenticate_user_with_token
        Rails.logger.info('nod-callbacks-74832 - Received request, authenticating')
        authenticate_with_http_token do |token|
          return false if bearer_token_secret.nil?

          token == bearer_token_secret
        end
      end

      def authenticity_error
        Rails.logger.info('nod-callbacks-74832 - Failed to authenticate request')
        render json: { message: 'Invalid credentials' }, status: :unauthorized
      end

      def bearer_token_secret
        Settings.dig(:simple_forms_vanotify_status_callback, :bearer_token)
      end
    end
  end
end
