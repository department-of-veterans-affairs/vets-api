# frozen_string_literal: true

module ClaimsApi
  class ClaimManagementService < ClaimsApi::LocalBGS
    def bean_name
      'ClaimManagementService/ClaimManagementService'
    end

    def find_claim_level_suspense(claim_id:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <claimId />
      EOXML

      { claimId: claim_id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: bean_name, action: 'findClaimLevelSuspense', body:, key: 'ClaimLevelSuspense')
    end

    def update_claim_level_suspense(claim:)
      camelcase_claim = to_camelcase(claim: claim[:benefit_claim])
      body = Nokogiri::XML(camelcase_claim.to_xml(skip_instruct: true, root: 'benefitClaim')).root

      make_request(endpoint: bean_name, action: 'updateClaimLevelSuspense', body:)
    end
  end
end
