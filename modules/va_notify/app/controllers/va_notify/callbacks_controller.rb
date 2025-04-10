# frozen_string_literal: true

require 'va_notify/default_callback'

module VANotify
  class CallbacksController < VANotify::ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    service_tag 'va-notify'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]

    before_action :authenticate_callback

    def create
      notification_id = params[:id]

      if (notification = VANotify::Notification.find_by(notification_id:))
        notification.update(notification_params)
        Rails.logger.info("va_notify callbacks - Updating notification: #{notification.id}",
                          {
                            source_location: notification.source_location,
                            template_id: notification.template_id,
                            callback_metadata: notification.callback_metadata,
                            status: notification.status,
                            status_reason: notification.status_reason
                          })

        VANotify::DefaultCallback.new(notification).call
        VANotify::CustomCallback.new(notification_params.merge(id: notification_id)).call
      else
        Rails.logger.info("va_notify callbacks - Received update for unknown notification #{notification_id}")
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

        if Flipper.enabled?(:va_notify_custom_bearer_tokens)
          service_callback_tokens.any? do |service_token|
            ActiveSupport::SecurityUtils.secure_compare(token, service_token)
          end
        else
          ActiveSupport::SecurityUtils.secure_compare(token, bearer_token_secret)
        end
      end
    end

    def authenticity_error
      Rails.logger.info('va_notify callbacks - Failed to authenticate request')
      render json: { message: 'Unauthorized' }, status: :unauthorized
    end

    def bearer_token_secret
      Settings.vanotify.status_callback.bearer_token
    end

    def service_callback_tokens
      Settings.vanotify.service_callback_tokens.to_h.values
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
