class Claim < ActiveModelSerializers::Model
  attr_accessor :id

  def self.fetch_all(headers)
    evss_client = EVSS::ClaimsService.new(headers)
    keys = %w(openClaims historicalClaims)
    raw_claims = evss_client.claims.body
    claims = []
    keys.each do |key|
      next unless raw_claims[key]
      claims << raw_claims[key].map do |raw_claim|
        attrs = {
          id: raw_claim["id"]
        }
        Claim.new(attrs)
      end
    end
    claims.flatten
  end
end
