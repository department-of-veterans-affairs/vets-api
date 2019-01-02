# frozen_string_literal: true

module ClaimsApi
  class ClaimDetailSerializer < EVSSClaimDetailSerializer
    include SerializerBase

    attribute :status
  end
end
