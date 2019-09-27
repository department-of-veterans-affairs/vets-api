# frozen_string_literal: true

module ClaimsApi
  class AutoEstablishedClaimSerializer < EVSSClaimDetailSerializer
    attributes :token, :status, :evss_id

    type :claims_api_claim

    def id
      object&.evss_id || object&.id
    end
  end
end
