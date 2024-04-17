# frozen_string_literal: true

module TravelPay
  class ClaimsController < ApplicationController
    before_action :authorize

    def index
      veis_token = client.request_veis_token
      # Non-intuitive Ruby behavior: #split splits a string on space by default
      vagov_token = request.headers['Authorization'].split[1]
      btsss_token = client.request_btsss_token(veis_token, vagov_token)

      begin
        claims = client.get_claims(veis_token, btsss_token)
      rescue Faraday::Error => e
        raise common_exception(e)
      end

      render json: claims, each_serializer: TravelPay::ClaimSerializer, status: :ok
    end

    private

    def client
      @client ||= TravelPay::Client.new
    end

    def common_exception(e)
      case e
      when Faraday::ResourceNotFound
        Common::Exceptions::ResourceNotFound.new
      else
        Common::Exceptions::InternalServerError.new
      end
    end
  end
end
