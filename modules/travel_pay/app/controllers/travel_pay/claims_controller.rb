# frozen_string_literal: true

module TravelPay
  class ClaimsController < ApplicationController
    def index
      byebug
      veis_token = client.request_veis_token
      vagov_token = request.headers['Authorization'].split(' ')[1]
      btsss_token = client.request_btsss_token(veis_token, vagov_token)

      claims = client.get_claims(veis_token, btsss_token)
      render json: claims, each_serializer: TravelPay::ClaimSerializer, status: :ok
    end

    private
    def client
      @client ||= TravelPay::Client.new
    end
  end
end
