require_dependency "evss"

class Claim < ActiveModelSerializers::Model
  attr_accessor :id

  EVSS_CLAIM_KEYS = %w(openClaims historicalClaims).freeze

  def self.fetch_all(headers)
    evss_client = EVSS::ClaimsService.new(headers)
    raw_claims = evss_client.claims.body
    EVSS_CLAIM_KEYS.each_with_object([]) do |key, claims|
      next unless raw_claims[key]
      claims << raw_claims[key].map do |raw_claim|
        attrs = {
          id: raw_claim["id"]
        }
        Claim.new(attrs)
      end
    end.flatten
  end
end
