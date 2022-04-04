# frozen_string_literal: true

require 'fitbit/client'

module DhpConnectedDevices
  class FitbitController < ApplicationController
    before_action :feature_enabled

    def connect
      auth_url = fitbit_api.auth_url_with_pkce
      redirect_to auth_url
    end

    private

    def fitbit_api
      @fitbit_client ||= DhpConnectedDevices::Fitbit::Client.new
    end

    def callback_params
      params.permit(:code)
    end

    def feature_enabled
      routing_error unless Flipper.enabled?(:dhp_connected_devices_fitbit)
    end
  end
end
