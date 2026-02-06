# frozen_string_literal: true

# The CallbackSignatureGenerator is responsible for generating HMAC-SHA256 signatures
# for payloads sent to VANotify callbacks. These signatures are used to verify the
# authenticity and integrity of the payloads.

require 'sidekiq/attr_package'
require 'va_notify/default_callback'
require 'va_notify/callback_signature_generator'

module VANotify
  class CallbacksController < VANotify::ApplicationController
    include ActionController::HttpAuthentication::Token::ControllerMethods

    UUID_LENGTH = 36

    service_tag 'va-notify'

    skip_before_action :verify_authenticity_token, only: [:create]
    skip_before_action :authenticate, only: [:create]

    before_action :set_notification, only: [:create]
    before_action :authenticate_callback!, only: [:create]

    def create
      notification_id = params[:id]
      if Flipper.enabled?(:va_notify_delivery_status_update_job)
        attr_package_params_cache_key = Sidekiq::AttrPackage.create(
          **notification_params.to_h.symbolize_keys
        )
        VANotify::DeliveryStatusUpdateJob.perform_async(notification_id, attr_package_params_cache_key)
        Rails.logger.info('va_notify callbacks - Enqueued DeliveryStatusUpdateJob',
                          { notification_id:, attr_package_params_cache_key: })
      elsif @notification
        @notification.update(notification_params)

        log_successful_update(@notification)

        VANotify::DefaultCallback.new(@notification).call
        VANotify::CustomCallback.new(notification_params.merge(id: notification_id)).call
      else
        Rails.logger.info(
          "va_notify callbacks - Received update for unknown notification #{notification_id}"
        )
      end

      render json: { message: 'success' }, status: :ok
    end

    private

    def log_successful_update(notification)
      Rails.logger.info("va_notify callbacks - Updating notification: #{notification.id}",
                        {
                          notification_id: notification.id,
                          source_location: notification.source_location,
                          template_id: notification.template_id,
                          callback_metadata: notification.callback_metadata,
                          status: notification.status,
                          status_reason: notification.status_reason
                        })
    end

    def set_notification
      notification_id = params[:id]
      @notification = VANotify::Notification.find_by(notification_id:)
    end

    def authenticate_callback!
      return if authenticate_token || authenticate_signature

      authenticity_error
    end

    def authenticate_signature
      return false unless @notification

      signature_from_header = request.headers['x-enp-signature'].to_s.strip

      return if signature_from_header.blank?

      api_key = get_api_key_value(@notification.service_id)
      if api_key.nil?
        Rails.logger.error("va_notify callbacks - Failed signature authentication
        due to missing API key for service_id #{@notification.service_id}")
        return false
      end

      signature = VANotify::CallbackSignatureGenerator.call(request.raw_post, api_key)

      ActiveSupport::SecurityUtils.secure_compare(signature, signature_from_header)
    end

    def authenticate_token
      authenticate_with_http_token do |token|
        service_callback_tokens.any? do |service_token|
          ActiveSupport::SecurityUtils.secure_compare(token, service_token)
        end
      end
    end

    def authenticity_error
      Rails.logger.info('va_notify callbacks - Failed to authenticate request')
      render json: { message: 'Unauthorized' }, status: :unauthorized
    end

    def service_callback_tokens
      Settings.vanotify.service_callback_tokens&.to_h&.values
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

    def get_api_key_value(service_id)
      service_config = Settings.vanotify.services.find do |_service, options|
        options.api_key&.include?(service_id)
      end
      if service_config.blank?
        Rails.logger.error("api key not found for service_id #{service_id}")
        return nil
      end

      computed_api_key = service_config[1].api_key
      extracted_value(computed_api_key)
    end

    def extracted_value(computed_api_key)
      computed_api_key[(computed_api_key.length - UUID_LENGTH)..computed_api_key.length]
    end
  end
end
