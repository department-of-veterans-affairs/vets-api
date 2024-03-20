# frozen_string_literal: true

module TravelPay
  class PingsController < ApplicationController
    def ping
      veis_response = client.request_veis_token

      veis_token = veis_response.body['access_token']

      btsss_ping_response = client.ping(veis_token)

      render json: { data: "Received ping from upstream server with status #{btsss_ping_response.status}." }
    end

    def client
      TravelPay::Client.new
    end
  end
end
