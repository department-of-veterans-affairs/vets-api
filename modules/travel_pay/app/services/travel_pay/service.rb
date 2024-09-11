# frozen_string_literal: true

module TravelPay
  class Service
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

    def get_claim_by_id(current_user, claim_id)

      # ensure claim ID is the right format
      uuid_v4_format = /^[0-9A-F]{8}-[0-9A-F]{4}-[4][0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/i

      unless uuid_v4_format.match?(claim_id)
        raise ArgumentError.new("Expected claim id to be a valid v4 UUID, got #{claim_id}.")
      end

      claims_response = client.get_claims(current_user)

      claims = claims_response.body['data']

      claims.find { |c| c['id'] == claim_id }
    end

    private

    def client
      TravelPay::Client.new
    end
  end
end
