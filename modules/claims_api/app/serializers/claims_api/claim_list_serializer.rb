# frozen_string_literal: true

module ClaimsApi
  class ClaimListSerializer < EVSSClaimListSerializer
    include SerializerBase

    attribute :status
  end
end
