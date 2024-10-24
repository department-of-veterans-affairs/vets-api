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
      claim[:bnft_claim_dto].transform_keys { |key| key.to_s.camelize :lower }

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <bnftClaimId />
      EOXML

      { bnftClaimId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: bean_name, action: 'updateBnftClaim',
                   body: { bnftClaimDTO: claim }, key: claim[:bnftClaimId])

      response.body[:update_bnft_claim_response]
    end
  end
end
