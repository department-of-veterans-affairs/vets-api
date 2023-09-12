# frozen_string_literal: true

module ClaimsApi
  class BenefitClaimService < ClaimsApi::LocalBGS
    def bean_name
      'BenefitClaimWebServiceBean/BenefitClaimWebService'
    end

    def find_bnft_claim(claim_id:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <bnftClaimId />
      EOXML

      { bnftClaimId: claim_id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: bean_name, action: 'findBnftClaim', body:)
    end

    def update_bnft_claim(claim_id:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <bnftClaimId />
      EOXML

      { bnftClaimId: claim_id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: bean_name, action: 'updateBnftClaim', body:)
    end
  end
end
