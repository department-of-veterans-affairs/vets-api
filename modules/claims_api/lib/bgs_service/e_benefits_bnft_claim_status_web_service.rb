# frozen_string_literal: true

module ClaimsApi
  class EbenefitsBnftClaimStatusWebService < ClaimsApi::LocalBGS
    def bean_name
      'EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService'
    end

    def find_benefit_claims_status_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId>#{id}</ptcpntId>
      EOXML

      make_request(endpoint: bean_name,
                   action: 'findBenefitClaimsStatusByPtcpntId', body:)
    end

    def find_benefit_claim_details_by_benefit_claim_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <bnftClaimId>#{id}</bnftClaimId>
      EOXML

      make_request(endpoint: bean_name,
                   action: 'findBenefitClaimDetailsByBnftClaimId', body:)
    end

    # BEGIN: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.
    def update_from_remote(id)
      bgs_claim = find_benefit_claim_details_by_benefit_claim_id(id)
      transform_bgs_claim_to_evss(bgs_claim)
    end

    def all(id)
      claims = find_benefit_claims_status_by_ptcpnt_id(id)
      return [] if claims.count < 1 || claims[:benefit_claims_dto].blank?

      transform_bgs_claims_to_evss(claims)
    end
    # END: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.

    def claims_count(id)
      find_benefit_claims_status_by_ptcpnt_id(id).count
    rescue ::Common::Exceptions::ResourceNotFound
      0
    end
  end
end
