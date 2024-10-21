# frozen_string_literal: true

module VANotify
  class CallbacksController < VANotify::ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    service_tag 'va-notify'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]

    before_action :authenticate_callback

    def create
      Rails.logger.debug { "Notification received: #{params.inspect}" }
      required_fields = %i[notification_id reference to status]
      missing_fields = required_fields.select { |field| params[:va_notify_notification][field].blank? }

      if missing_fields.any?
        render json: { errors: { message: 'Missing required fields' } }, status: :unprocessable_entity
        return
      end

      va_notify_notification = VANotify::Notification.new(notification_params)
      va_notify_notification.save!
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

    def notification_params
      params.require(:va_notify_notification).permit(
        :notification_id,
        :reference,
        :to,
        :status,
        :completed_at,
        :sent_at,
        :notification_type,
        :status_reason,
        :provider,
        :source_location,
        :callback
      )
    end
  end
end
