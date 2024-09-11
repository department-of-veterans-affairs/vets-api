# frozen_string_literal: true

module TravelPay
  class ClaimsService
    def get_claims(current_user)
      claims_response = client.get_claims(current_user)
      symbolized_body = claims_response.body.deep_symbolize_keys

      {
        data: symbolized_body[:data].map do |sc|
          sc[:claimStatus] = sc[:claimStatus].underscore.titleize
          sc
        end
      }
    end

    private

    def client
      TravelPay::ClaimsClient.new
    end
  end
end
