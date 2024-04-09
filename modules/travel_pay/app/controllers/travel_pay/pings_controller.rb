# frozen_string_literal: true

module TravelPay
  class PingsController < ApplicationController
    before_action :authorize, only: [:authorized_ping]

    def ping
      veis_token = client.request_veis_token

      btsss_ping_response = client.ping(veis_token)

      render json: { data: "Received ping from upstream server with status #{btsss_ping_response.status}." }
    end

    def authorized_ping
      vagov_token = request.headers['Authorization'].split[1]
      veis_token = client.request_veis_token
      btsss_token = client.request_btsss_token(veis_token, vagov_token)

      btsss_authorized_ping_response = client.authorized_ping(veis_token, btsss_token)
      render json: {
        data: "Received authorized ping from upstream server with status #{btsss_authorized_ping_response.status}."
      }
    end

    def client
      TravelPay::Client.new
    end
  end
end
