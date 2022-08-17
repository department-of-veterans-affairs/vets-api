# frozen_string_literal: true

require 'fitbit/client'

module DhpConnectedDevices
  module Fitbit
    class FitbitController < ApplicationController
      include SentryLogging
      before_action :feature_enabled

      def connect
        auth_url = fitbit_api.auth_url_with_pkce
        redirect_to auth_url
      end

      def callback
        auth_code = fitbit_api.get_auth_code(callback_params)
        token_json = fitbit_api.get_token(auth_code)
        token_storage_service.store_tokens(@current_user, 'fitbit', token_json)
        VeteranDeviceRecordsService.create_or_activate(@current_user, 'fitbit')
        redirect_with_status('success')
      rescue => e
        Rails.logger.warn("Fitbit callback error: #{e}")
        log_error(e)
        redirect_with_status('error')
      end

      def disconnect
        VeteranDeviceRecordsService.deactivate(@current_user, 'fitbit')
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
        routing_error unless Flipper.enabled?(:dhp_connected_devices_fitbit)
      end

      def redirect_with_status(status)
        redirect_to website_host_service.get_redirect_url({ status: status, vendor: 'fitbit' })
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
