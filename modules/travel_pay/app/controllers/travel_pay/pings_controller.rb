# frozen_string_literal: true

module TravelPay
  class PingsController < ApplicationController
    skip_before_action :authenticate, only: :ping

    def ping
      btsss_ping_response = service.ping

      render json: { data: "Received ping from upstream server with status #{btsss_ping_response.status}." }
    end

    def authorized_ping
      btsss_authorized_ping_response = service.authorized_ping(@current_user)
      render json: {
        data: "Received authorized ping from upstream server with status #{btsss_authorized_ping_response.status}."
      }
    end

    def client
      TravelPay::Client.new
    end

    def service
      TravelPay::Service.new
    end
  end
end
