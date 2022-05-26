# frozen_string_literal: true

require 'fitbit/client'

module DhpConnectedDevices
  class FitbitController < ApplicationController
    before_action :feature_enabled

    def connect
      auth_url = fitbit_api.auth_url_with_pkce
      redirect_to auth_url
    end

    def callback
      status = fitbit_service.get_connection_status({ callback_params: callback_params, fitbit_api: fitbit_api })
      VeteranDeviceRecordsService.create_or_activate(@current_user, 'fitbit') if status == 'success'
      redirect_with_status(status)
    rescue => e
      log_error e
      redirect_with_status('error')
    end

    def disconnect
      VeteranDeviceRecordsService.deactivate(@current_user, 'fitbit')
      redirect_with_status('disconnect-success')
    rescue => e
      log_error e
      redirect_with_status('disconnect-error')
    end

    private

    def fitbit_api
      @fitbit_client ||= DhpConnectedDevices::Fitbit::Client.new
    end

    def fitbit_service
      @fitbit_service ||= FitbitService.new
    end

    def website_host_service
      @website_host_service ||= WebsiteHostService.new
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
