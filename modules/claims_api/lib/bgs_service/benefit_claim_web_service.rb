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

    #
    # used to update the Benefit Claim row (by Benefit Claim ID) outside of the Claims Establishment
    # (CEST) process.  A call to findBnftClaim should be made prior to calling this method, as each value
    # returned in findBnftClaim should be passed as input to updateBnftClaim, along with any updates.
    # Failure to call findBnftClaim and provide all the date runs a risk of data corruption.
    #
    def update_bnft_claim(claim:)
      camelcase_claim = to_camelcase(claim: claim[:bnft_claim_dto])
      body = Nokogiri::XML(camelcase_claim.to_xml(skip_instruct: true, root: 'bnftClaimDTO')).root

      make_request(endpoint: bean_name, action: 'updateBnftClaim', body:)
    end

    def find_bnft_claim_by_clmant_id(dependent_participant_id:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntClmantId>#{dependent_participant_id}</ptcpntClmantId>
      EOXML

      make_request(endpoint: bean_name, action: 'findBnftClaimByPtcpntClmantId', body:)
    end
  end
end
