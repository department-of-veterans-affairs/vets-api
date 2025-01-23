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

    def update_bnft_claim(claim:)
      camelcase_claim = to_camelcase(claim: claim[:bnft_claim_dto])
      body = Nokogiri::XML(camelcase_claim.to_xml(skip_instruct: true, root: 'bnftClaimDTO')).root
      make_request(endpoint: bean_name, action: 'updateBnftClaim',
                   body:)
    end
  end
end
