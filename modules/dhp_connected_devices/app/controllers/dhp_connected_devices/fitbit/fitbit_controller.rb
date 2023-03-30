# frozen_string_literal: true

require 'fitbit/client'

module DhpConnectedDevices
  module Fitbit
    class FitbitController < ApplicationController
      include SentryLogging
      before_action :feature_enabled
      before_action :user_verified

      def connect
        auth_url = fitbit_api.auth_url_with_pkce
        redirect_to auth_url
      end

      def callback
        auth_code = fitbit_api.get_auth_code(callback_params)
        token_json = fitbit_api.get_token(auth_code)
        token_storage_service.store_tokens(@current_user, device_key, token_json)
        VeteranDeviceRecordsService.create_or_activate(@current_user, device_key)
        redirect_with_status('success')
      rescue => e
        Rails.logger.warn("Fitbit callback error: #{e}")
        log_error(e)
        redirect_with_status('error')
      end

      def disconnect
        token = token_storage_service.get_token(@current_user, device_key)
        fitbit_api.revoke_token(token[:payload])
        token_storage_service.send(:delete_token, @current_user, device_key)
        VeteranDeviceRecordsService.deactivate(@current_user, device_key)
        redirect_with_status('disconnect-success')
      rescue => e
        Rails.logger.warn("Fitbit disconnection error: #{e}")
        log_error(e)
        redirect_with_status('disconnect-error')
      end

      private

      def fitbit_api
        @fitbit_client ||= DhpConnectedDevices::Fitbit::Client.new
      end

      def device_key
        'fitbit'
      end

      def website_host_service
        @website_host_service ||= WebsiteHostService.new
      end

      def token_storage_service
        @token_storage_service ||= TokenStorageService.new
      end

      def callback_params
        params.permit(:code, :error, :error_detail)
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:dhp_connected_devices_fitbit, @current_user)
      end

      def user_verified
        connection_unavailable_error if @current_user&.icn.blank?
      end

      def connection_unavailable_error
        Rails.logger.warn('Device connection unavailable for Veterans without an ICN')
        log_message_to_sentry('User with an invalid ICN value attempted to connect their Fitbit', 'warn')
        raise Common::Exceptions::Forbidden.new(
          detail: 'User with an invalid ICN value attempted to connect their Fitbit',
          source: 'FitbitController'
        )
      end

      def redirect_with_status(status)
        redirect_to website_host_service.get_redirect_url({ status:, vendor: device_key })
      end

      def log_error(error)
        log_exception_to_sentry(
          error,
          {
            icn: @current_user&.icn
          }
        )
      end
    end
  end
end
