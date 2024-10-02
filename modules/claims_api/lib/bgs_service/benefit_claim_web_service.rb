# frozen_string_literal: true

module ClaimsApi
  class BenefitClaimWebService < ClaimsApi::LocalBGS
    def bean_name
      'BenefitClaimWebServiceBean/BenefitClaimWebService'
    end

    def find_bnft_claim(claim_id:)
      builder = Nokogiri::XML::Builder.new do
        bnftClaimId claim_id
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'findBnftClaim', body:)
    end
  end
end
