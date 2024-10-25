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
      claim = claim[:bnft_claim_dto].transform_keys { |key| key.to_s.camelize :lower }

      # body = claim.map do |k, value|
      #   item = Nokogiri::XML::DocumentFragment.parse <<~EOXML
      #     <#{k} />
      #   EOXML
      #   item.xpath("./*[local-name()='#{k}']")[0].content = value
      # end
      # debugger
      make_request(endpoint: bean_name, action: 'updateBnftClaim',
                   body: { bnftClaimDTO: claim, bnftClaimId: claim[:bnftClaimId] })
      response.body[:update_bnft_claim_response]
    end
  end
end
