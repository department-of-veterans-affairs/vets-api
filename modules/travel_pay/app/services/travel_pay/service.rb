# frozen_string_literal: true

module TravelPay
  class Service
    def get_claims(current_user)
      claims_response = client.get_claims(current_user)
      symbolized_body = claims_response.body.deep_symbolize_keys
      parse_claim_date = ->(c) { Date.parse(c[:appointmentDateTime]) }

      sorted_claims = symbolized_body[:data].sort_by(&parse_claim_date).reverse

      {
        data: sorted_claims.map do |sc|
          sc[:claimStatus] = sc[:claimStatus].underscore.titleize
          sc
        end
      }
    end

    private

    def client
      TravelPay::Client.new
    end
  end
end
