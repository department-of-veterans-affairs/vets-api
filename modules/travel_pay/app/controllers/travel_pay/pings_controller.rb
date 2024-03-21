# frozen_string_literal: true

module TravelPay
  class PingsController < ApplicationController
    def ping
      veis_response = client.request_veis_token

      veis_token = veis_response.body['access_token']

      btsss_ping_response = client.ping(veis_token)

      render json: { data: "Received ping from upstream server with status #{btsss_ping_response.status}." }
    end

    def authorized_ping
      veis_response = client.request_veis_token
      veis_token = veis_response.body['access_token']

      vagov_token = request.headers['Authorization'].split[1]

      btsss_response = client.request_btsss_token(veis_token, vagov_token)
      btsss_token = JSON.parse(btsss_response.body)['access_token']

      btsss_authorized_ping_response = client.authorized_ping(veis_token, btsss_token)
    end

    def client
      TravelPay::Client.new
    end
  end
end
