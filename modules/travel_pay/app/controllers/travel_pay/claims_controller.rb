# frozen_string_literal: true

module TravelPay
  class ClaimsController < ApplicationController
    ##
    # For now, index is integrated with PING endpoint until
    # upstream API is more complete.
    def index
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
