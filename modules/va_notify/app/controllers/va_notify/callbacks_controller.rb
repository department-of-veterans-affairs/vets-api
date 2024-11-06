# frozen_string_literal: true

module VANotify
  class CallbacksController < VANotify::ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    service_tag 'va-notify'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]

    before_action :authenticate_callback

    def create
      Rails.logger.info { "Notification received: #{params.inspect}" }
      notification_id = params[:id]

      if (notification = VANotify::Notification.find_by(notification_id: notification_id))
        Rails.logger.info("va_notify callbacks - Updating notification #{notification.id}")
        notification.update(notification_params)
        # default callback for all notifications
        VANotify::WatchOfficerCallback.call(notification)
        # team specific callbacks
        VANotify::StatusUpdate.new.delegate(notification_params.merge(id: notification_id))
      else
        Rails.logger.error("va_notify callbacks - Received update for unknown notification #{notification_id}")
      end

      render json: { message: 'success' }, status: :ok
    end

    private

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
      Settings.vanotify.status_callback.bearer_token
    end

    def notification_params
      params.permit(
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
