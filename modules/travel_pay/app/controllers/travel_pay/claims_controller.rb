# frozen_string_literal: true

module TravelPay
  class ClaimsController < ApplicationController
    def index
      claims = client.get_claims
      render json: claims, each_serializer: TravelPay::ClaimSerializer, status: :ok
    end

    private
    def client
      TravelPay::Client.new
    end
  end
end
